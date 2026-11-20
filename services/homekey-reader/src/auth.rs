use crate::{
    apdu::{command, field, fields, parse, select, Card},
    secure::{derive, Channel},
    state::{endpoint_id, fixed, random, Endpoint, Home},
};
use anyhow::{ensure, Context, Result};
use p256::{
    ecdh::diffie_hellman,
    ecdsa::{
        signature::{Signer, Verifier},
        Signature, SigningKey, VerifyingKey,
    },
    elliptic_curve::sec1::ToEncodedPoint,
    PublicKey, SecretKey,
};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};
use subtle::ConstantTimeEq;

#[derive(Clone, Copy, Default, PartialEq, Eq, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Flow {
    #[default]
    Fast,
    Standard,
    Attestation,
}

pub struct Authenticated {
    pub issuer: String,
    pub endpoint: Endpoint,
}
impl Authenticated {
    pub fn record(mut self, home: &mut Home) -> Result<()> {
        let id = endpoint_id(&hex::decode(&self.endpoint.public_key)?);
        ensure!(
            !home.revoked.contains(&format!("{}/{id}", self.issuer)) && self.endpoint.valid_now(),
            "credential revoked"
        );
        let issuer = home
            .issuers
            .get_mut(&self.issuer)
            .context("issuer was removed")?;
        self.endpoint.counter = self
            .endpoint
            .counter
            .checked_add(1)
            .context("counter exhausted")?;
        self.endpoint.last_used_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)?
            .as_secs();
        issuer.endpoints.insert(id, self.endpoint);
        Ok(())
    }
}

pub fn authenticate(card: &mut impl Card, home: &Home, flow: Flow) -> Result<Authenticated> {
    transaction(
        card,
        home,
        flow,
        SecretKey::random(&mut OsRng),
        random::<16>(),
        random::<32>(),
    )
}

fn transaction(
    card: &mut impl Card,
    home: &Home,
    flow: Flow,
    secret: SecretKey,
    nonce: [u8; 16],
    attestation_secret: [u8; 32],
) -> Result<Authenticated> {
    let (reader, id) = home.reader()?;
    let selected = select(card, 1)?;
    let tags = parse(&selected)?;
    let offered = field(&tags, 0x5c)?;
    ensure!(
        offered.len() % 2 == 0 && offered.chunks_exact(2).any(|v| v == [2, 0]),
        "unsupported Home Key version"
    );
    let version = fields(&[(0x5c, &[2, 0])]);
    let versions = fields(&[(0x5c, offered)]);
    let ephemeral = secret.public_key().to_encoded_point(false);
    let rx = ephemeral.x().unwrap().as_slice();
    let flags = [u8::from(flow == Flow::Fast), 1];
    let interface = [0x5e];
    let challenge = fields(&[
        (0x5c, &[2, 0]),
        (0x87, ephemeral.as_bytes()),
        (0x4c, &nonce),
        (0x4d, &id),
    ]);
    let result = command(card, [0x80, 0x80, flags[0], flags[1]], &challenge, None)?;
    let reply = parse(&result)?;
    let peer = PublicKey::from_sec1_bytes(field(&reply, 0x86)?)?;
    let peer_point = peer.to_encoded_point(false);
    let ex = peer_point.x().unwrap().as_slice();
    if let Some(proof) = reply.get(&0x9d).filter(|_| flow == Flow::Fast) {
        ensure!(proof.len() == 16, "invalid FAST proof size");
        let reader_pub = reader.public_key().to_encoded_point(false);
        for (issuer_id, issuer) in &home.issuers {
            for endpoint in issuer.endpoints.values() {
                let pk = PublicKey::from_sec1_bytes(&hex::decode(&endpoint.public_key)?)?
                    .to_encoded_point(false);
                let info = [
                    reader_pub.x().unwrap().as_slice(),
                    b"VolatileFast",
                    &id,
                    pk.x().unwrap().as_slice(),
                    &interface,
                    &versions,
                    &version,
                    rx,
                    &nonce,
                    &flags,
                    ex,
                ]
                .concat();
                let expected = derive::<16>(&fixed::<32>(&endpoint.persistent_key)?, None, &info);
                if bool::from(expected.as_slice().ct_eq(proof)) {
                    ensure!(endpoint.valid_now(), "credential outside validity interval");
                    command(card, [0x80, 0x3c, 1, 0], &[], None)?;
                    return Ok(Authenticated {
                        issuer: issuer_id.clone(),
                        endpoint: endpoint.clone(),
                    });
                }
            }
        }
    }
    let transcript = |context: u32| {
        fields(&[
            (0x4d, &id),
            (0x86, ex),
            (0x87, rx),
            (0x4c, &nonce),
            (0x93, &context.to_be_bytes()),
        ])
    };
    let signature: Signature = SigningKey::from(reader).sign(&transcript(1096652137));
    let auth1 = command(
        card,
        [0x80, 0x81, 0, 0],
        &fields(&[(0x9e, &signature.to_bytes())]),
        None,
    )?;
    let shared = diffie_hellman(secret.to_nonzero_scalar(), peer.as_affine());
    let seed = Sha256::new()
        .chain_update(shared.raw_secret_bytes())
        .chain_update(1u32.to_be_bytes())
        .chain_update(nonce)
        .finalize();
    let info = |ctx: &[u8]| [rx, ex, &nonce, &interface, &flags, ctx, &version, &versions].concat();
    let persistent = derive::<32>(&seed, None, &info(b"Persistent"));
    let mut channel = Channel::new(derive(&seed, None, &info(b"Volatile")));
    let clear = channel.open(&auth1)?;
    let signed = parse(&clear)?;
    let eid = hex::encode(field(&signed, 0x4e)?);
    ensure!(eid.len() == 12, "unknown or revoked credential");
    let sig = Signature::from_slice(field(&signed, 0x9e)?)?;
    let known = home
        .issuers
        .iter()
        .find_map(|(i, v)| v.endpoints.get(&eid).map(|e| (i.clone(), e.clone())));
    let known = known.filter(|_| flow != Flow::Attestation);
    let attesting = known.is_none();
    let (issuer, mut endpoint) = if let Some(pair) = known {
        pair
    } else {
        let (issuer, mut attested) =
            crate::attestation::enroll(card, &mut channel, home, attestation_secret)?;
        ensure!(
            attested.valid_now(),
            "attestation outside validity interval"
        );
        if let Some(previous) = home.issuers[&issuer].endpoints.get(&eid) {
            ensure!(
                attested.public_key == previous.public_key,
                "attested key changed"
            );
            attested.counter = previous.counter;
            if let Some(hap) = &previous.enrollments.hap {
                attested.enrollments.hap = Some(hap.clone());
                attested.validity = None;
            }
        }
        (issuer, attested)
    };
    ensure!(
        !home.revoked.contains(&format!("{issuer}/{eid}")) && endpoint.valid_now(),
        "credential expired or revoked"
    );
    let pubkey = hex::decode(&endpoint.public_key)?;
    ensure!(
        eid == endpoint_id(&pubkey),
        "attestation belongs to a different device"
    );
    VerifyingKey::from_sec1_bytes(&pubkey)?.verify(&transcript(1317567308), &sig)?;
    if !attesting {
        command(card, [0x80, 0x3c, 1, 0], &[], None)?;
    }
    endpoint.persistent_key = hex::encode(persistent);
    Ok(Authenticated { issuer, endpoint })
}
#[cfg(test)]
mod tests;
