use super::*;
use crate::state::State;
use hap_crypto::{
    aead::{chacha20poly1305_open, chacha20poly1305_seal},
    PairSetupClient, PairSetupStep, PairVerifyClient, PairVerifyStep,
};
use std::io::{BufRead, BufReader, Read, Write};

fn message(method: &str, path: &str, body: &[u8]) -> Vec<u8> {
    [
        format!(
            "{method} {path} HTTP/1.1\r\nContent-Length: {}\r\n\r\n",
            body.len()
        )
        .as_bytes(),
        body,
    ]
    .concat()
}
fn post(socket: &mut TcpStream, path: &str, body: &[u8]) -> Result<Vec<u8>> {
    socket.write_all(&message("POST", path, body))?;
    let mut r = BufReader::new(socket);
    let mut line = String::new();
    let mut length = None;
    loop {
        line.clear();
        ensure!(r.read_line(&mut line)? > 0, "early close");
        if line == "\r\n" {
            break;
        }
        if let Some(n) = line.strip_prefix("Content-Length: ") {
            length = Some(n.trim().parse::<usize>()?);
        }
    }
    let mut data = vec![0; length.context("missing length")?];
    r.read_exact(&mut data)?;
    Ok(data)
}
#[test]
fn pair_verify_provision_and_revoke_over_ip() -> Result<()> {
    let dir = tempfile::tempdir()?;
    let store = Arc::new(Store::create(dir.path(), || Ok(State::fresh()))?);
    let server = Arc::new(Server {
        store: store.clone(),
        pin: "378-90-214".into(),
        port: 0,
        mdns: None,
        setup: Mutex::new(Instant::now()),
        active: AtomicUsize::new(0),
        finish: "black".into(),
    });
    let listener = TcpListener::bind("127.0.0.1:0")?;
    let addr = listener.local_addr()?;
    let s = server.clone();
    let worker = thread::spawn(move || {
        let (socket, _) = listener.accept().unwrap();
        let _ = s.connection(socket);
    });
    let mut socket = TcpStream::connect(addr)?;
    socket.set_read_timeout(Some(Duration::from_secs(8)))?;
    let cid = "7CA012B1-DAEF-46DE-9435-1F1D5D5071DB";
    let controller = ControllerKeypair::generate(cid.into());
    let mut setup = PairSetupClient::new(
        &server.pin,
        ControllerKeypair::from_seed(cid.into(), controller.seed()),
    )?;
    let mut request = setup.start();
    let accessory = loop {
        match setup.handle(&post(&mut socket, "/pair-setup", &request)?)? {
            PairSetupStep::Send(next) => request = next,
            PairSetupStep::Done(a) => break a,
        }
    };
    let mut verify = PairVerifyClient::new(&controller, &accessory);
    request = verify.start();
    let keys = loop {
        match verify.handle(&post(&mut socket, "/pair-verify", &request)?)? {
            PairVerifyStep::Send(next) => request = next,
            PairVerifyStep::Done(k) => break k,
        }
    };
    let mut ctr = 0u64;
    let mut exchange = |method: &str, path: &str, data: &[u8]| -> Result<Vec<u8>> {
        let msg = message(method, path, data);
        let len = (msg.len() as u16).to_le_bytes();
        let nonce = crypto::nonce_counter(ctr);
        socket.write_all(&len)?;
        socket.write_all(&chacha20poly1305_seal(&keys.write_key, &nonce, &len, &msg)?)?;
        let mut len = [0; 2];
        socket.read_exact(&mut len)?;
        let mut payload = vec![0; u16::from_le_bytes(len) as usize + 16];
        socket.read_exact(&mut payload)?;
        ctr += 1;
        Ok(chacha20poly1305_open(
            &keys.read_key,
            &nonce,
            &len,
            &payload,
        )?)
    };
    let provision = tlv(&[
        (1, &[2]),
        (6, &tlv(&[(1, &[2]), (2, &[9; 32]), (3, &[8; 8])])),
    ]);
    let update =
        json!({"characteristics":[{"aid":1,"iid":17,"value":STANDARD.encode(provision),"r":true}]});
    let response = String::from_utf8(exchange(
        "PUT",
        "/characteristics",
        &serde_json::to_vec(&update)?,
    )?)?;
    ensure!(
        response.starts_with("HTTP/1.1 207")
            && response.contains(&STANDARD.encode(tlv(&[(7, &tlv(&[(2, &[0])]))]))),
        "write response missing"
    );
    ensure!(
        store.snapshot()?.home.reader().is_ok(),
        "reader provisioning lost"
    );
    let remove = tlv(&[(6, &[1]), (0, &[4]), (1, cid.as_bytes())]);
    exchange("POST", "/pairings", &remove)?;
    assert!(store.snapshot()?.hap.controllers.is_empty());
    assert!(store.snapshot()?.home.reader().is_err());
    drop(socket);
    worker.join().unwrap();
    Ok(())
}

#[test]
fn provisioning_and_removal_follow_the_credential_issuer() -> Result<()> {
    use p256::elliptic_curve::sec1::ToEncodedPoint;
    let mut s = State::fresh();
    let owner = "owner";
    let public = ed25519_dalek::SigningKey::from_bytes(&[9; 32])
        .verifying_key()
        .to_bytes();
    s.hap.add_controller(owner, &public, 1)?;
    s.sync_issuers()?;
    let get_reader = tlv(&[(1, &[1]), (6, &[])]);
    assert!(provision::control(&mut s, owner, &get_reader)?.is_empty());
    let issuer = crate::state::key_id(&public);
    let device = p256::SecretKey::from_slice(&[5; 32])?
        .public_key()
        .to_encoded_point(false);
    let eid = hex::decode(crate::state::endpoint_id(device.as_bytes()))?;
    let add = tlv(&[
        (1, &[2]),
        (
            4,
            &tlv(&[
                (1, &[2]),
                (2, &device.as_bytes()[1..]),
                (3, &issuer),
                (4, &[1]),
            ]),
        ),
    ]);
    assert_eq!(
        provision::control(&mut s, owner, &add)?,
        tlv(&[(5, &tlv(&[(2, &issuer), (3, &[0])]))])
    );
    let remove = tlv(&[(1, &[3]), (4, &tlv(&[(5, &eid)]))]);
    assert_eq!(
        provision::control(&mut s, owner, &remove)?,
        tlv(&[(5, &tlv(&[(3, &[0])]))])
    );
    assert!(s
        .home
        .revoked
        .contains(&format!("{}/{}", hex::encode(issuer), hex::encode(&eid))));
    assert!(s.home.issuers[&hex::encode(issuer)].endpoints.is_empty());
    let dir = tempfile::tempdir()?;
    let store = Store::create(dir.path(), || Ok(s))?;
    let rev = store.snapshot()?.revision;
    store.update(|s| provision::control(s, owner, &get_reader))?;
    assert_eq!(store.snapshot()?.revision, rev);
    for seed in 20..36 {
        let key = p256::SecretKey::from_slice(&[seed; 32])?
            .public_key()
            .to_encoded_point(false);
        let grant = tlv(&[
            (1, &[2]),
            (
                4,
                &tlv(&[(2, &key.as_bytes()[1..]), (3, &issuer), (4, &[1])]),
            ),
        ]);
        store.update(|s| provision::control(s, owner, &grant))?;
    }
    let full_revision = store.snapshot()?.revision;
    let response = store.update(|s| provision::control(s, owner, &add))?;
    assert_eq!(response, tlv(&[(5, &tlv(&[(2, &issuer), (3, &[1])]))]));
    assert_eq!(store.snapshot()?.revision, full_revision);
    drop(store);
    let store = Store::open(dir.path())?;
    assert!(store.snapshot()?.home.revoked.contains(&format!(
        "{}/{}",
        hex::encode(issuer),
        hex::encode(&eid)
    )));
    Ok(())
}

#[test]
fn inactive_legacy_grant_wins_over_attestation_on_import_and_reopen() -> Result<()> {
    use p256::elliptic_curve::sec1::ToEncodedPoint;
    let dir = tempfile::tempdir()?;
    let mut s = State::fresh();
    let public = ed25519_dalek::SigningKey::from_bytes(&[11; 32])
        .verifying_key()
        .to_bytes();
    s.hap.add_controller("owner", &public, 1)?;
    s.sync_issuers()?;
    let issuer = crate::state::key_id(&public);
    let pk = p256::SecretKey::from_slice(&[7; 32])?
        .public_key()
        .to_encoded_point(false);
    let eid = crate::state::endpoint_id(pk.as_bytes());
    let raw = |active| tlv(&[(2, &pk.as_bytes()[1..]), (3, &issuer), (4, &[active])]);
    provision::control(&mut s, "owner", &tlv(&[(1, &[2]), (4, &raw(1))]))?;
    let ep = s
        .home
        .issuers
        .get_mut(&hex::encode(issuer))
        .unwrap()
        .endpoints
        .get_mut(&eid)
        .unwrap();
    ep.enrollments = serde_json::from_value(
        json!({"hap":{"payload":STANDARD.encode(raw(0))},"attestation":{"at":1}}),
    )?;
    let hap = dir.path().join("python-hap");
    let home = dir.path().join("python-home");
    std::fs::write(&hap, serde_json::to_vec(&s.hap)?)?;
    std::fs::write(&home, serde_json::to_vec(&s.home)?)?;
    std::fs::write(dir.path().join("state.json"), serde_json::to_vec(&s)?)?;
    let check = |s: &State| {
        assert!(s
            .home
            .revoked
            .contains(&format!("{}/{}", hex::encode(issuer), eid)));
        assert!(s.home.issuers[&hex::encode(issuer)].endpoints.is_empty());
    };
    check(&State::import(&hap, &home)?);
    check(Store::open(dir.path())?.snapshot()?.as_ref());
    check(&serde_json::from_reader(std::fs::File::open(
        dir.path().join("state.json"),
    )?)?);
    Ok(())
}
