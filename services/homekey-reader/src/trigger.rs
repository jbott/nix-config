use anyhow::{ensure, Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use esphome_client::types::{
    ConnectRequest, DisconnectRequest, EspHomeMessage, ExecuteServiceArgument,
    ExecuteServiceRequest, ListEntitiesRequest, PingResponse, ServiceArgType,
    SubscribeStatesRequest, SwitchCommandRequest,
};
mod wire;
use serde::Deserialize;
use std::{
    fs,
    path::PathBuf,
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};
use tokio::{sync::mpsc, time::timeout};
use wire::Client;
const MAX_AGE: Duration = Duration::from_millis(750);
#[derive(Deserialize, Default)]
#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
pub enum Action {
    #[default]
    DryRun,
    Esphome {
        address: String,
        entity: String,
        psk_file: PathBuf,
        #[serde(default)]
        receiver_expiry: bool,
    },
}
type Connection = Arc<Mutex<Option<mpsc::Sender<Instant>>>>;
pub struct Trigger(Option<Connection>);
impl Trigger {
    pub fn start(action: Action) -> Result<Self> {
        let Action::Esphome {
            address,
            entity,
            psk_file,
            receiver_expiry,
        } = action
        else {
            return Ok(Self(None));
        };
        let key = read_psk(&psk_file)?;
        ensure!(
            !entity.is_empty() && !address.is_empty(),
            "missing ESPHome address or switch"
        );
        let connection = Arc::new(Mutex::new(None));
        let worker = connection.clone();
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()?;
        thread::Builder::new()
            .name("esphome".into())
            .spawn(move || {
                runtime.block_on(async move {
                    loop {
                        let (session, address, entity, key) =
                            (worker.clone(), address.clone(), entity.clone(), key.clone());
                        match tokio::spawn(async move {
                            connected(&session, &address, &entity, &key, receiver_expiry).await
                        })
                        .await
                        {
                            Ok(Ok(())) => (),
                            Ok(Err(error)) => eprintln!("ESPHome session ended: {error}"),
                            Err(_) => eprintln!("ESPHome session worker exited unexpectedly"),
                        }
                        *worker.lock().unwrap() = None;
                        eprintln!("ESPHome unavailable, reconnecting");
                        tokio::time::sleep(Duration::from_secs(3)).await;
                    }
                })
            })?;
        Ok(Self(Some(connection)))
    }
    pub fn authenticated(&self) {
        match &self.0 {
            None => eprintln!("authenticated Home Key (dry run)"),
            Some(c) => {
                let sent = c
                    .lock()
                    .unwrap()
                    .as_ref()
                    .is_some_and(|tx| tx.try_send(Instant::now()).is_ok());
                if !sent {
                    eprintln!("authenticated tap dropped: switch unavailable or busy")
                }
            }
        }
    }
}

fn read_psk(path: &std::path::Path) -> Result<String> {
    let key = fs::read_to_string(path).context("reading ESPHome credential")?;
    let key = key.trim();
    ensure!(
        STANDARD.decode(key)?.len() == 32,
        "invalid ESPHome credential"
    );
    Ok(key.into())
}

pub fn check_switch(address: &str, entity: &str, psk_file: &std::path::Path) -> Result<()> {
    let key = read_psk(psk_file)?;
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()?;
    runtime.block_on(async {
        let (mut client, _) = discover(address, entity, &key, false).await?;
        timeout(Duration::from_secs(2), client.send(DisconnectRequest {})).await??;
        Ok(())
    })
}

enum Target {
    Switch(u32),
    Expiring { prepare: u32, commit: u32, ack: u32 },
}

impl Target {
    async fn pulse(&self, client: &mut Client, tap: Instant) -> Result<()> {
        match *self {
            Self::Switch(key) => client.send(SwitchCommandRequest { key, state: true }).await,
            Self::Expiring {
                prepare,
                commit,
                ack,
            } => {
                let token = hex::encode(crate::state::random::<16>());
                let arg = ExecuteServiceArgument {
                    string: token.clone(),
                    ..Default::default()
                };
                client
                    .send(ExecuteServiceRequest {
                        key: prepare,
                        args: vec![arg.clone()],
                    })
                    .await?;
                loop {
                    match client.recv().await? {
                        EspHomeMessage::TextSensorStateResponse(s)
                            if s.key == ack && !s.missing_state && s.state == token =>
                        {
                            break
                        }
                        EspHomeMessage::PingRequest(_) => client.send(PingResponse {}).await?,
                        EspHomeMessage::DisconnectRequest(_) => anyhow::bail!("disconnected"),
                        _ => (),
                    }
                }
                // The gate started its timer before this echo arrived. Giving
                // it only the remaining local budget is conservative without
                // synchronizing clocks, even if TCP delays the commit.
                let left = MAX_AGE.saturating_sub(tap.elapsed()).as_millis() as i32;
                ensure!(left > 0, "tap expired before gate acknowledgement");
                client
                    .send(ExecuteServiceRequest {
                        key: commit,
                        args: vec![
                            arg,
                            ExecuteServiceArgument {
                                int: left,
                                ..Default::default()
                            },
                        ],
                    })
                    .await
            }
        }
    }
}

async fn discover(
    addr: &str,
    entity: &str,
    secret: &str,
    receiver_expiry: bool,
) -> Result<(Client, Target)> {
    timeout(Duration::from_secs(10), async {
        let mut client = Client::open(addr, secret).await?;
        // Pre-2026 devices require an empty login even on an encrypted session.
        // Newer firmware ignores this message. Only discovery gates readiness.
        client.send(ConnectRequest::default()).await?;
        client.send(ListEntitiesRequest {}).await?;
        let mut found = None;
        let (mut prepare, mut commit, mut ack) = (None, None, None);
        let prepare_name = format!("{entity}_homekey_prepare");
        let commit_name = format!("{entity}_homekey_commit");
        let ack_name = format!("{entity}_homekey_ack");
        loop {
            match client.recv().await? {
                EspHomeMessage::PingRequest(_) => client.send(PingResponse {}).await?,
                EspHomeMessage::ConnectResponse(r) if r.invalid_password => {
                    anyhow::bail!("ESPHome rejected login")
                }
                EspHomeMessage::ListEntitiesSwitchResponse(s) if s.object_id == entity => {
                    ensure!(found.replace(s.key).is_none(), "ambiguous switch");
                }
                EspHomeMessage::ListEntitiesServicesResponse(s)
                    if receiver_expiry && (s.name == prepare_name || s.name == commit_name) =>
                {
                    let args: Vec<_> = s.args.iter().map(|a| (a.name.as_str(), a.r#type)).collect();
                    let token = ("token", ServiceArgType::String as i32);
                    if s.name == prepare_name {
                        ensure!(
                            args == [token] && prepare.replace(s.key).is_none(),
                            "invalid prepare service"
                        );
                    } else {
                        ensure!(
                            args == [token, ("remaining_ms", ServiceArgType::Int as i32)]
                                && commit.replace(s.key).is_none(),
                            "invalid commit service"
                        );
                    }
                }
                EspHomeMessage::ListEntitiesTextSensorResponse(s)
                    if receiver_expiry && s.object_id == ack_name =>
                {
                    ensure!(
                        ack.replace(s.key).is_none(),
                        "ambiguous acknowledgement sensor"
                    );
                }
                EspHomeMessage::ListEntitiesDoneResponse(_) => break,
                _ => (),
            }
        }
        let key = found.context("configured switch missing")?;
        let target = if receiver_expiry {
            let target = Target::Expiring {
                prepare: prepare.context("gate prepare service missing")?,
                commit: commit.context("gate commit service missing")?,
                ack: ack.context("gate acknowledgement sensor missing")?,
            };
            client.send(SubscribeStatesRequest {}).await?;
            target
        } else {
            Target::Switch(key)
        };
        Ok::<_, anyhow::Error>((client, target))
    })
    .await?
}

async fn connected(
    shared: &Connection,
    addr: &str,
    entity: &str,
    secret: &str,
    receiver_expiry: bool,
) -> Result<()> {
    let (mut client, target) = discover(addr, entity, secret, receiver_expiry).await?;
    let (sender, mut events) = mpsc::channel(1);
    *shared.lock().unwrap() = Some(sender);
    eprintln!("ESPHome switch ready");
    loop {
        tokio::select! {
          message = client.recv() => match message? {
            EspHomeMessage::DisconnectRequest(_) => anyhow::bail!("disconnected"),
            EspHomeMessage::PingRequest(_) => timeout(Duration::from_secs(2),client.send(PingResponse {})).await??,
            _ => (),
          },
          tap = events.recv() => {
            let Some(tap) = tap else { return Ok(()) };
            let Some(remaining) = MAX_AGE.checked_sub(tap.elapsed()) else {
                continue;
            };
            timeout(
                remaining,
                target.pulse(&mut client, tap),
            )
            .await??;
            eprintln!("sent authenticated switch command");
          }
        }
    }
}
#[cfg(test)]
mod tests;
