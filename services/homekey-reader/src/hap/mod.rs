mod crypto;
mod pairing;
mod provision;
mod wire;

use crate::state::{fixed, Home, Store};
use anyhow::{ensure, Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use hap_crypto::ControllerKeypair;
use hap_tlv8::{Tlv8Map, Tlv8Writer};
use mdns_sd::{ServiceDaemon, ServiceInfo};
use pairing::SetupInProgress;
use provision::tlv;
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    net::{SocketAddr, TcpListener, TcpStream},
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc, Mutex,
    },
    thread,
    time::{Duration, Instant},
};
use wire::{Reply, Request, Wire};

pub struct Server {
    store: Arc<Store>,
    pin: String,
    port: u16,
    mdns: Option<ServiceDaemon>,
    setup: Mutex<Instant>,
    active: AtomicUsize,
    finish: String,
}
impl Server {
    pub fn listen(store: Arc<Store>, bind: SocketAddr, pin: String, finish: String) -> Result<()> {
        let listener = TcpListener::bind(bind)?;
        let server = Arc::new(Self {
            store,
            pin,
            port: listener.local_addr()?.port(),
            mdns: Some(ServiceDaemon::new()?),
            setup: Mutex::new(Instant::now()),
            active: AtomicUsize::new(0),
            finish,
        });
        server.announce()?;
        for socket in listener.incoming() {
            let socket = socket?;
            if server.active.fetch_add(1, Ordering::Relaxed) >= 32 {
                server.active.fetch_sub(1, Ordering::Relaxed);
                continue;
            }
            let server = server.clone();
            thread::spawn(move || {
                let _ = server.connection(socket);
                server.active.fetch_sub(1, Ordering::Relaxed);
            });
        }
        Ok(())
    }
    fn announce(&self) -> Result<()> {
        let state = self.store.snapshot()?;
        let id = &state.hap.accessory.mac;
        let host = format!("homekey-{}.local.", id.replace(':', "").to_lowercase());
        let props: HashMap<String, String> = [
            ("id", id.to_owned()),
            ("md", "NFC Lock".into()),
            ("c#", state.hap.accessory.config_version.to_string()),
            ("ff", "0".into()),
            ("ci", "6".into()),
            ("pv", "1.1".into()),
            ("s#", "1".into()),
            (
                "sf",
                if state.hap.controllers.is_empty() {
                    "1"
                } else {
                    "0"
                }
                .into(),
            ),
        ]
        .into_iter()
        .map(|(k, v)| (k.into(), v))
        .collect();
        let Some(mdns) = &self.mdns else {
            return Ok(());
        };
        mdns.register(
            ServiceInfo::new("_hap._tcp.local.", "NFC Lock", &host, "", self.port, props)?
                .enable_addr_auto(),
        )?;
        Ok(())
    }
    fn connection(&self, socket: TcpStream) -> Result<()> {
        socket.set_read_timeout(Some(Duration::from_secs(90)))?;
        socket.set_write_timeout(Some(Duration::from_secs(10)))?;
        let mut wire = Wire::new(socket);
        let mut setup = None;
        let mut verify = None;
        let mut peer: Option<(String, String)> = None;
        let mut subscriptions = std::collections::BTreeSet::new();
        loop {
            let req = wire.request()?;
            let s = self.store.snapshot()?;
            if let Some((id, key)) = &peer {
                ensure!(s.hap.paired_key(id, key).is_some(), "pairing removed");
                let reply = match (
                    req.method.as_str(),
                    req.path.split('?').next().unwrap_or(""),
                ) {
                    ("GET", "/accessories") => Reply::json(200, self.database()),
                    ("GET", "/characteristics") => self.read(&req.path, &subscriptions)?,
                    ("PUT", "/characteristics") => self.write(id, key, &req, &mut subscriptions)?,
                    ("POST", "/pairings") => {
                        let before = s.hap.controllers.is_empty();
                        let result = self.pairings(id, key, &req.body);
                        if before != self.store.snapshot()?.hap.controllers.is_empty() {
                            self.announce()?;
                        }
                        Reply::tlv(result.unwrap_or_else(|_| pair_error(2, 2)))
                    }
                    _ => Reply::empty(404),
                };
                wire.reply(reply)?;
                continue;
            }
            let kp = ControllerKeypair::from_seed(
                s.hap.accessory.mac.clone(),
                fixed(&s.hap.accessory.private_key)?,
            );
            if req.method != "POST" {
                wire.reply(Reply::empty(470))?;
                return Ok(());
            }
            match req.path.as_str() {
                "/identify" if s.hap.controllers.is_empty() => wire.reply(Reply::empty(204))?,
                "/pair-setup" => {
                    let stage = Tlv8Map::parse(&req.body)?
                        .get_u8(6)?
                        .context("missing stage")?;
                    if !s.hap.controllers.is_empty() {
                        wire.reply(Reply::tlv(pair_error(2, 6)))?;
                        return Ok(());
                    }
                    match (stage, setup.take()) {
                        (1, _) => {
                            let mut gate = self.setup.lock().unwrap();
                            if Instant::now() < *gate {
                                wire.reply(Reply::tlv(pair_error(2, 7)))?;
                                return Ok(());
                            }
                            *gate = Instant::now() + Duration::from_secs(2);
                            drop(gate);
                            let (msg, next) = pairing::handle_setup_m1(&self.pin, &req.body)?;
                            setup = Some(next);
                            wire.reply(Reply::tlv(msg))?;
                        }
                        (3, Some(SetupInProgress::AwaitingM3 { server })) => {
                            let (msg, secret) = pairing::handle_setup_m3(&server, &req.body)?;
                            setup = secret
                                .map(|session_key| SetupInProgress::AwaitingM5 { session_key });
                            wire.reply(Reply::tlv(msg))?;
                        }
                        (5, Some(SetupInProgress::AwaitingM5 { session_key })) => {
                            let (msg, pair) = pairing::handle_setup_m5(
                                &session_key,
                                &kp,
                                &s.hap.accessory.mac,
                                &req.body,
                            )?;
                            if let Some((id, key)) = pair {
                                let saved = self.store.update(|s| {
                                    ensure!(s.hap.controllers.is_empty(), "already paired");
                                    s.hap.add_controller(&id, &key, 1)?;
                                    s.sync_issuers()
                                });
                                if saved.is_err() {
                                    wire.reply(Reply::tlv(pair_error(6, 6)))?;
                                    return Ok(());
                                }
                                self.announce()?;
                            }
                            wire.reply(Reply::tlv(msg))?;
                        }
                        _ => {
                            wire.reply(Reply::tlv(pair_error(stage.saturating_add(1), 2)))?;
                            return Ok(());
                        }
                    }
                }
                "/pair-verify" => match Tlv8Map::parse(&req.body)?.get_u8(6)? {
                    Some(1) => {
                        let (msg, next) = pairing::handle_m1(&kp, &s.hap.accessory.mac, &req.body)?;
                        verify = Some(next);
                        wire.reply(Reply::tlv(msg))?;
                    }
                    Some(3) => {
                        let pending = verify.take().context("missing verification")?;
                        let mut verified = None;
                        for (id, controller) in &s.hap.controllers {
                            let raw = controller.wire_id(id);
                            let (msg, keys) = pairing::handle_m3(
                                &pending,
                                std::str::from_utf8(raw)?,
                                &fixed(&controller.public_key)?,
                                &req.body,
                            )?;
                            if let Some(keys) = keys {
                                verified =
                                    Some((msg, keys, id.clone(), controller.public_key.clone()));
                                break;
                            }
                        }
                        if let Some((msg, keys, id, key)) = verified {
                            wire.reply(Reply::tlv(msg))?;
                            wire.upgrade(keys)?;
                            peer = Some((id, key));
                        } else {
                            wire.reply(Reply::tlv(pair_error(4, 2)))?;
                            return Ok(());
                        }
                    }
                    _ => anyhow::bail!("invalid verification stage"),
                },
                _ => {
                    wire.reply(Reply::empty(470))?;
                    return Ok(());
                }
            }
        }
    }
    fn pairings(&self, id: &str, key: &str, input: &[u8]) -> Result<Vec<u8>> {
        let m = Tlv8Map::parse(input)?;
        ensure!(m.get_u8(6)? == Some(1), "invalid pairing stage");
        let method = m.get_u8(0)?.context("missing method")?;
        let mut out = tlv(&[(6, &[2])]);
        if method == 5 {
            let s = self.store.snapshot()?;
            ensure!(
                s.hap.paired_key(id, key).is_some_and(|c| c.admin),
                "administrator required"
            );
            let mut w = Tlv8Writer::new(&mut out);
            for (index, (pid, controller)) in s.hap.controllers.iter().enumerate() {
                if index > 0 {
                    w.push_separator()
                }
                w.push(1, controller.wire_id(pid));
                w.push(3, &fixed::<32>(&controller.public_key)?);
                w.push_u8(11, u8::from(controller.admin));
            }
            return Ok(out);
        }
        let wire_id = std::str::from_utf8(m.get(1).context("missing identifier")?)?;
        self.store.update(|s| {
            ensure!(
                s.hap.paired_key(id, key).is_some_and(|c| c.admin),
                "administrator required"
            );
            match method {
                3 => s.hap.add_controller(
                    wire_id,
                    m.get(3).context("missing key")?.try_into()?,
                    m.get_u8(11)?.context("missing permissions")?,
                )?,
                4 => {
                    if let Some(pid) = s.hap.controller_id(wire_id.as_bytes()).cloned() {
                        s.hap.controllers.remove(&pid);
                    }
                }
                _ => anyhow::bail!("unknown pairing method"),
            }
            if !s.hap.controllers.values().any(|c| c.admin) {
                s.hap.controllers.clear();
                s.home = Home::default();
            }
            s.sync_issuers()
        })?;
        Ok(out)
    }
    fn database(&self) -> Value {
        let mut db: Value = serde_json::from_str(include_str!("accessories.json"))
            .expect("checked accessory layout");
        let color = match self.finish.as_str() {
            "silver" => [0xe3, 0xe3, 0xe3, 0],
            "gold" => [0xaa, 0xd6, 0xec, 0],
            "tan" => [0xce, 0xd5, 0xda, 0],
            _ => [0; 4],
        };
        for s in db["accessories"][0]["services"].as_array_mut().unwrap() {
            for c in s["characteristics"].as_array_mut().unwrap() {
                if c["iid"] == 8 {
                    c["value"] = STANDARD.encode(tlv(&[(1, &color)])).into()
                }
            }
        }
        db
    }
    fn read(&self, path: &str, subscriptions: &std::collections::BTreeSet<u64>) -> Result<Reply> {
        let query: HashMap<_, _> = path
            .split_once('?')
            .context("missing query")?
            .1
            .split('&')
            .filter_map(|p| p.split_once('='))
            .collect();
        let db = self.database();
        let mut chars = Vec::new();
        let mut errors = false;
        for pk in query.get("id").context("missing id")?.split(',') {
            let (a, i) = pk.split_once('.').context("invalid id")?;
            let aid = a.parse::<u64>()?;
            let iid = i.parse::<u64>()?;
            let mut out = json!({"aid":aid,"iid":iid});
            let item = if aid == 1 { find(&db, iid) } else { None };
            if let Some(c) = item.filter(|c| has(c, "pr")) {
                out["value"] = c["value"].clone();
                if query.get("type") == Some(&"1") {
                    out["type"] = c["type"].clone();
                }
                if query.get("perms") == Some(&"1") {
                    out["perms"] = c["perms"].clone();
                }
                if query.get("ev") == Some(&"1") {
                    out["ev"] = subscriptions.contains(&iid).into();
                }
                if query.get("meta") == Some(&"1") {
                    for k in [
                        "format",
                        "minValue",
                        "maxValue",
                        "minStep",
                        "valid-values",
                        "unit",
                        "maxLen",
                    ] {
                        if let Some(v) = c.get(k) {
                            out[k] = v.clone();
                        }
                    }
                }
            } else {
                errors = true;
                out["status"] = if item.is_none() {
                    (-70409).into()
                } else {
                    (-70405).into()
                };
            }
            chars.push(out);
        }
        if errors {
            for c in &mut chars {
                if c.get("status").is_none() {
                    c["status"] = 0.into();
                }
            }
        }
        Ok(Reply::json(
            if errors { 207 } else { 200 },
            json!({"characteristics":chars}),
        ))
    }
    fn write(
        &self,
        id: &str,
        key: &str,
        req: &Request,
        subs: &mut std::collections::BTreeSet<u64>,
    ) -> Result<Reply> {
        let request: Value = serde_json::from_slice(&req.body)?;
        let db = self.database();
        let mut items = Vec::new();
        let mut respond = false;
        for c in request["characteristics"]
            .as_array()
            .context("missing writes")?
        {
            let iid = c["iid"].as_u64().context("missing iid")?;
            let mut r = json!({"aid":c["aid"],"iid":iid,"status":0});
            let item = find(&db, iid);
            if c["aid"] != 1 || item.is_none() {
                r["status"] = (-70409).into();
            } else {
                let item = item.unwrap();
                if let Some(ev) = c.get("ev") {
                    if !has(item, "ev") || !ev.is_boolean() {
                        r["status"] = (-70406).into();
                    } else if ev == true {
                        subs.insert(iid);
                    } else {
                        subs.remove(&iid);
                    }
                }
                if let Some(value) = c.get("value") {
                    if !has(item, "pw") {
                        r["status"] = (-70404).into();
                    } else if iid == 17 {
                        let result = (|| -> Result<_> {
                            let raw = STANDARD.decode(value.as_str().context("expected TLV8")?)?;
                            self.store.update(|s| {
                                ensure!(s.hap.paired_key(id, key).is_some(), "pairing removed");
                                provision::control(s, id, &raw)
                            })
                        })();
                        match result {
                            Ok(v) if c["r"] == true => {
                                r["value"] = STANDARD.encode(v).into();
                                respond = true;
                            }
                            Ok(_) => (),
                            Err(_) => r["status"] = (-70410).into(),
                        }
                    } else if iid == 11 && !matches!(value.as_u64(), Some(0 | 1)) {
                        r["status"] = (-70410).into();
                    }
                }
            }
            respond |= r["status"] != 0;
            items.push(r);
        }
        Ok(if respond {
            Reply::json(207, json!({"characteristics":items}))
        } else {
            Reply::empty(204)
        })
    }
}
fn find(db: &Value, iid: u64) -> Option<&Value> {
    db["accessories"][0]["services"]
        .as_array()?
        .iter()
        .flat_map(|s| s["characteristics"].as_array().into_iter().flatten())
        .find(|c| c["iid"] == iid)
}
fn has(c: &Value, perm: &str) -> bool {
    c["perms"]
        .as_array()
        .is_some_and(|p| p.iter().any(|v| v == perm))
}
fn pair_error(stage: u8, err: u8) -> Vec<u8> {
    tlv(&[(6, &[stage]), (7, &[err])])
}

#[cfg(test)]
mod tests;
