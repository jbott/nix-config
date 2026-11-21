// SPDX-License-Identifier: MIT OR Apache-2.0

use anyhow::{bail, ensure, Context, Result};
use homekey_reader::{
    apdu::Card,
    auth::{authenticate, Flow},
    hap::Server,
    nfc::Reader,
    state::{State, Store},
    trigger::{Action, Trigger},
};
use serde::Deserialize;
use std::{
    env, fs,
    net::SocketAddr,
    path::{Path, PathBuf},
    sync::Arc,
    thread,
    time::{Duration, Instant},
};

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Config {
    device: PathBuf,
    state_dir: PathBuf,
    bind: SocketAddr,
    setup_pin_file: PathBuf,
    #[serde(default = "yes")]
    express: bool,
    #[serde(default)]
    flow: Flow,
    #[serde(default = "black")]
    finish: String,
    #[serde(default)]
    trigger: TriggerConfig,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum TriggerConfig {
    File(PathBuf),
    Inline(Action),
}

impl Default for TriggerConfig {
    fn default() -> Self {
        Self::Inline(Action::DryRun)
    }
}

impl TriggerConfig {
    fn load(self) -> Result<Action> {
        match self {
            Self::Inline(action) => Ok(action),
            Self::File(path) => {
                ensure!(path.is_absolute(), "expected absolute trigger file path");
                let file = fs::File::open(&path)
                    .with_context(|| format!("open trigger file {}", path.display()))?;
                serde_json::from_reader(file)
                    .with_context(|| format!("parse trigger file {}", path.display()))
            }
        }
    }
}
fn yes() -> bool {
    true
}
fn black() -> String {
    "black".into()
}
struct Target<'a> {
    reader: &'a mut Reader,
    id: u8,
}
impl Card for Target<'_> {
    fn exchange(&mut self, apdu: &[u8]) -> Result<Vec<u8>> {
        self.reader.exchange(self.id, apdu)
    }
}
// Preserve the physical presentation across serial sessions. Only sustained
// empty polls from a working reader can rearm a dispatched presentation.
#[derive(Default)]
struct Presentation {
    armed: bool,
    empty_since: Option<Instant>,
}
impl Presentation {
    fn observe(&mut self, present: bool, now: Instant) -> bool {
        if present {
            self.empty_since = None;
        } else if now.duration_since(*self.empty_since.get_or_insert(now)) >= Duration::from_secs(1)
        {
            self.armed = true;
        }
        self.armed && present
    }
    fn dispatched(&mut self) {
        self.armed = false;
    }
}
fn scan(
    reader: &mut Reader,
    store: &Store,
    trigger: &Trigger,
    express: bool,
    flow: Flow,
    presentation: &mut Presentation,
) -> Result<()> {
    loop {
        let state = store.snapshot()?;
        if let Ok((_, id)) = state.home.reader() {
            let target = reader.poll(id[..8].try_into()?, express)?;
            let accept = presentation.observe(target.is_some(), Instant::now());
            if let Some(target) = target {
                if accept {
                    let result =
                        authenticate(&mut Target { reader, id: target }, &state.home, flow);
                    match result {
                        Ok(authenticated) => {
                            let recorded = store.update(|s| {
                                ensure!(
                                    s.revision == state.revision,
                                    "provisioning changed during tap"
                                );
                                authenticated.record(&mut s.home)
                            });
                            if recorded.is_ok() {
                                presentation.dispatched();
                                trigger.authenticated()
                            } else {
                                eprintln!("tap discarded: could not commit current authorization");
                            }
                        }
                        Err(_) => eprintln!("card authentication unsuccessful"),
                    }
                }
                reader.wait_for_removal()?;
                reader.release(target)?;
            }
        }
        thread::sleep(Duration::from_millis(150));
    }
}
fn serve(config: &Path) -> Result<()> {
    let c: Config = serde_json::from_reader(fs::File::open(config)?)?;
    ensure!(c.device.is_absolute(), "expected absolute UART path");
    ensure!(
        matches!(c.finish.as_str(), "silver" | "gold" | "black" | "tan"),
        "invalid finish"
    );
    let pin = fs::read_to_string(c.setup_pin_file)?.trim().to_string();
    let digits = pin.replace('-', "");
    ensure!(
        digits.len() == 8
            && digits.bytes().all(|b| b.is_ascii_digit())
            && pin == format!("{}-{}-{}", &digits[..3], &digits[3..5], &digits[5..])
            && !digits.as_bytes().iter().all(|d| *d == digits.as_bytes()[0])
            && digits != "12345678"
            && digits != "87654321",
        "invalid HomeKit setup PIN"
    );
    let store = Arc::new(Store::open(&c.state_dir)?);
    let trigger = Trigger::start(c.trigger.load()?)?;
    let reader_store = store.clone();
    thread::Builder::new().name("pn532".into()).spawn(move || {
        let mut presentation = Presentation::default();
        loop {
            presentation.empty_since = None;
            let res = Reader::open(&c.device).and_then(|mut r| {
                eprintln!("PN532 ready");
                scan(
                    &mut r,
                    &reader_store,
                    &trigger,
                    c.express,
                    c.flow,
                    &mut presentation,
                )
            });
            if let Err(e) = res {
                eprintln!("PN532 unavailable: {e}");
            }
            thread::sleep(Duration::from_secs(3));
        }
    })?;
    Server::listen(store, c.bind, pin, c.finish)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn external_trigger_uses_the_current_file_or_reports_an_error() -> Result<()> {
        let dir = tempfile::tempdir()?;
        let path = dir.path().join("trigger.json");
        let setting = serde_json::to_value(&path)?;
        let load = || serde_json::from_value::<TriggerConfig>(setting.clone())?.load();
        assert!(load().is_err());
        fs::write(
            &path,
            r#"{"type":"esphome","address":"device.local:6053","entity":"relay","psk_file":"/key"}"#,
        )?;
        assert!(matches!(load()?, Action::Esphome { entity, .. } if entity == "relay"));
        fs::write(&path, r#"{"type":"dry_run"}"#)?;
        assert!(matches!(load()?, Action::DryRun));
        fs::write(&path, r#"{"type":"esphome"}"#)?;
        assert!(load().is_err());
        Ok(())
    }

    #[test]
    fn held_presentation_needs_continuous_absence_after_reopen() {
        let start = Instant::now();
        let mut latch = Presentation::default();
        latch.observe(false, start);
        latch.observe(false, start + Duration::from_secs(1));
        assert!(latch.observe(true, start + Duration::from_secs(2)));
        latch.dispatched();
        latch.observe(false, start + Duration::from_secs(3));
        latch.empty_since = None; // UART reopens
        assert!(!latch.observe(true, start + Duration::from_secs(6)));
        latch.observe(false, start + Duration::from_secs(7));
        assert!(!latch.observe(true, start + Duration::from_millis(7400)));
        latch.observe(false, start + Duration::from_secs(8));
        latch.observe(false, start + Duration::from_secs(9));
        assert!(latch.observe(true, start + Duration::from_secs(10)));
    }
}
fn main() -> Result<()> {
    let args = env::args_os()
        .skip(1)
        .map(PathBuf::from)
        .collect::<Vec<_>>();
    let verb = args
        .first()
        .and_then(|s| s.to_str())
        .context("expected init, import or serve")?;
    match (verb, &args[1..]) {
        ("init", [dir]) => {
            Store::create(dir, || Ok(State::fresh()))?;
        }
        ("import", [hap, home, dir]) => {
            Store::create(dir, || State::import(hap, home))?;
        }
        ("check-import", [hap, home]) => {
            State::import(hap, home)?;
            println!("HomeKit identity, pairings and Home Key state validated");
        }
        ("check-switch", [addr, entity, psk]) => {
            homekey_reader::trigger::check_switch(addr.to_str().context("invalid address")?, entity.to_str().context("invalid entity")?, psk)?;
            println!("Encrypted ESPHome connection and switch discovery succeeded");
        }
        ("serve", [config]) => serve(config)?,
        _ => bail!(concat!(
            "usage: homekey-reader init STATE_DIR | ",
            "import HAP_STATE HOMEKEY_JSON STATE_DIR | ",
            "check-import HAP_STATE HOMEKEY_JSON | check-switch ADDRESS ENTITY PSK_FILE | serve CONFIG_JSON"
        )),
    }
    Ok(())
}
