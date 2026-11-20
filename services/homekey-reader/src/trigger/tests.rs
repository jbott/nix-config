use super::*;
use esphome_client::types::{HelloResponse, ListEntitiesDoneResponse, ListEntitiesSwitchResponse};
use snow::TransportState;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::{TcpListener, TcpStream},
};

async fn receive(s: &mut TcpStream) -> Result<Vec<u8>> {
    ensure!(s.read_u8().await? == 1, "unexpected plaintext");
    let n = s.read_u16().await?;
    let mut b = vec![0; n.into()];
    s.read_exact(&mut b).await?;
    Ok(b)
}
async fn send(s: &mut TcpStream, b: &[u8]) -> Result<()> {
    s.write_u8(1).await?;
    s.write_u16(b.len().try_into()?).await?;
    if let Some((last, rest)) = b.split_last() {
        s.write_all(rest).await?;
        tokio::time::sleep(Duration::from_millis(2)).await;
        s.write_all(&[*last]).await?;
    }
    Ok(())
}

#[tokio::test]
async fn frame_writer_completes_short_writes() -> Result<()> {
    let (mut writer, mut reader) = tokio::io::duplex(2);
    let (sent, read) = tokio::join!(wire::write_frame(&mut writer, b"fragmented"), async {
        let mut bytes = [0; 13];
        reader.read_exact(&mut bytes).await?;
        Ok::<_, std::io::Error>(bytes)
    });
    sent?;
    assert_eq!(&read?, b"\x01\x00\x0afragmented");
    Ok(())
}
async fn message(s: &mut TcpStream, n: &mut TransportState) -> Result<EspHomeMessage> {
    let ct = receive(s).await?;
    let mut b = vec![0; ct.len()];
    let len = n.read_message(&ct, &mut b)?;
    b.truncate(len);
    EspHomeMessage::try_from(b).map_err(|_| anyhow::anyhow!("invalid message"))
}
async fn answer(
    s: &mut TcpStream,
    n: &mut TransportState,
    msg: impl Into<EspHomeMessage>,
) -> Result<()> {
    let data: Vec<u8> = msg.into().into();
    let mut ct = vec![0; data.len() + 16];
    let len = n.write_message(&data, &mut ct)?;
    send(s, &ct[..len]).await
}
#[derive(Clone, Copy, PartialEq)]
enum Mode {
    Legacy,
    Guarded,
    MissingEcho,
}
async fn fake_switch(listener: TcpListener, mode: Mode) -> Result<()> {
    let (mut s, _) = listener.accept().await?;
    let mut hs = snow::Builder::new("Noise_NNpsk0_25519_ChaChaPoly_SHA256".parse()?)
        .prologue(b"NoiseAPIInit\0\0")?
        .psk(0, &[8; 32])?
        .build_responder()?;
    ensure!(receive(&mut s).await?.is_empty(), "client hello");
    let m = receive(&mut s).await?;
    hs.read_message(&m[1..], &mut [0; 256])?;
    send(&mut s, b"\x01test-switch\0").await?;
    let mut out = [0; 100];
    let n = hs.write_message(&[], &mut out[1..])?;
    send(&mut s, &out[..n + 1]).await?;
    let mut n = hs.into_transport_mode()?;
    ensure!(
        matches!(
            message(&mut s, &mut n).await?,
            EspHomeMessage::HelloRequest(_)
        ),
        "expected hello"
    );
    answer(
        &mut s,
        &mut n,
        HelloResponse {
            api_version_major: 1,
            api_version_minor: 10,
            ..Default::default()
        },
    )
    .await?;
    ensure!(
        matches!(
            message(&mut s, &mut n).await?,
            EspHomeMessage::ConnectRequest(_)
        ),
        "legacy login missing"
    );
    answer(
        &mut s,
        &mut n,
        esphome_client::types::ConnectResponse::default(),
    )
    .await?;
    ensure!(
        matches!(
            message(&mut s, &mut n).await?,
            EspHomeMessage::ListEntitiesRequest(_)
        ),
        "expected discovery"
    );
    answer(
        &mut s,
        &mut n,
        ListEntitiesSwitchResponse {
            object_id: "test_gate".into(),
            key: 42,
            ..Default::default()
        },
    )
    .await?;
    if mode != Mode::Legacy {
        use esphome_client::types::{
            ListEntitiesServicesArgument, ListEntitiesServicesResponse,
            ListEntitiesTextSensorResponse,
        };
        let token = ListEntitiesServicesArgument {
            name: "token".into(),
            r#type: ServiceArgType::String as i32,
        };
        let ttl = ListEntitiesServicesArgument {
            name: "remaining_ms".into(),
            r#type: ServiceArgType::Int as i32,
        };
        for (name, key, args) in [
            ("prepare", 1, vec![token.clone()]),
            ("commit", 2, vec![token, ttl]),
        ] {
            answer(
                &mut s,
                &mut n,
                ListEntitiesServicesResponse {
                    name: format!("test_gate_homekey_{name}"),
                    key,
                    args,
                },
            )
            .await?;
        }
        answer(
            &mut s,
            &mut n,
            ListEntitiesTextSensorResponse {
                object_id: "test_gate_homekey_ack".into(),
                key: 3,
                ..Default::default()
            },
        )
        .await?;
    }
    answer(&mut s, &mut n, ListEntitiesDoneResponse {}).await?;
    if mode != Mode::Legacy {
        use esphome_client::types::TextSensorStateResponse;
        ensure!(
            matches!(
                message(&mut s, &mut n).await?,
                EspHomeMessage::SubscribeStatesRequest(_)
            ),
            "no state subscription"
        );
        let EspHomeMessage::ExecuteServiceRequest(prepare) = message(&mut s, &mut n).await? else {
            anyhow::bail!("expected prepare")
        };
        ensure!(
            prepare.key == 1 && prepare.args.len() == 1 && prepare.args[0].string.len() == 32,
            "bad prepare"
        );
        answer(
            &mut s,
            &mut n,
            TextSensorStateResponse {
                key: 3,
                state: "old acknowledgement".into(),
                ..Default::default()
            },
        )
        .await?;
        if mode == Mode::MissingEcho {
            ensure!(
                timeout(Duration::from_secs(2), message(&mut s, &mut n))
                    .await?
                    .is_err(),
                "expired tap sent commit"
            );
            return Ok(());
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
        answer(
            &mut s,
            &mut n,
            TextSensorStateResponse {
                key: 3,
                state: prepare.args[0].string.clone(),
                ..Default::default()
            },
        )
        .await?;
        let EspHomeMessage::ExecuteServiceRequest(commit) = message(&mut s, &mut n).await? else {
            anyhow::bail!("expected commit")
        };
        ensure!(
            commit.key == 2
                && commit.args.len() == 2
                && commit.args[0] == prepare.args[0]
                && (1..=700).contains(&commit.args[1].int),
            "invalid commit or deadline"
        );
    } else {
        match message(&mut s, &mut n).await? {
            EspHomeMessage::SwitchCommandRequest(cmd) => {
                ensure!(cmd.key == 42 && cmd.state, "wrong switch command")
            }
            _ => anyhow::bail!("expected switch command"),
        }
    }
    ensure!(
        timeout(Duration::from_millis(100), receive(&mut s))
            .await
            .is_err(),
        "duplicate pulse"
    );
    Ok(())
}
#[tokio::test]
async fn stale_and_offline_events_never_pulse_reconnected_switch() -> Result<()> {
    run(Mode::Legacy).await
}
#[tokio::test]
async fn guarded_gate_needs_matching_echo_within_deadline() -> Result<()> {
    run(Mode::Guarded).await?;
    run(Mode::MissingEcho).await
}
async fn run(mode: Mode) -> Result<()> {
    let listener = TcpListener::bind("127.0.0.1:0").await?;
    let addr = listener.local_addr()?.to_string();
    let conn: Connection = Default::default();
    let trigger = Trigger(Some(conn.clone()));
    trigger.authenticated(); // offline
    let client = tokio::spawn({
        let conn = conn.clone();
        async move {
            connected(
                &conn,
                &addr,
                "test_gate",
                &STANDARD.encode([8; 32]),
                mode != Mode::Legacy,
            )
            .await
        }
    });
    let server = tokio::spawn(fake_switch(listener, mode));
    timeout(Duration::from_secs(5), async {
        loop {
            if conn.lock().unwrap().is_some() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        let tx = conn.lock().unwrap().clone().unwrap();
        tx.send(Instant::now() - Duration::from_secs(2)).await?;
        tx.reserve().await?.send(Instant::now());
        server.await??;
        Ok::<_, anyhow::Error>(())
    })
    .await??;
    client.abort();
    Ok(())
}
