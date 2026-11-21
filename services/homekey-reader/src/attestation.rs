// SPDX-License-Identifier: Apache-2.0
// Home Key protocol port based on kormax/apple-home-key-reader. See NOTICE.

//! ISO 18013 handover and issuer verification for a first presentation.
use crate::{
    apdu::{command, field, fields, parse, select, Card},
    secure::{derive, Channel},
    state::{fixed, Endpoint, Enrollments, Home},
};
use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes128Gcm,
};
use anyhow::{ensure, Context, Result};
use ciborium::Value as V;
use ed25519_dalek::{Signature, VerifyingKey};
use sha2::{Digest, Sha256};

const HANDOVER:&str="91021e48721591020263720102510211616301036e6663010a6d646f637265616465721c11010369736f2e6f72673a31383031333a6e66636e6663015c1e090a69736f2e6f72673a31383031333a726561646572656e676167656d656e746d646f63726561646572a20063312e30208129";
const DOC: &str = "com.apple.HomeKit.1.credential";
fn bytes(data: &[u8]) -> V {
    V::Bytes(data.to_vec())
}
fn map(items: Vec<(&str, V)>) -> V {
    V::Map(
        items
            .into_iter()
            .map(|(k, v)| (V::Text(k.into()), v))
            .collect(),
    )
}
fn serialize(v: &V) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    ciborium::into_writer(v, &mut out)?;
    Ok(out)
}
fn decode(mut data: &[u8]) -> Result<V> {
    let v = ciborium::de::from_reader_with_recursion_limit(&mut data, 32)?;
    ensure!(data.is_empty(), "trailing CBOR data");
    Ok(v)
}
fn tagged(b: &[u8]) -> V {
    V::Tag(24, Box::new(bytes(b)))
}
fn lookup<'a>(v: &'a V, key: V) -> Result<&'a V> {
    let mut values = v
        .as_map()
        .context("expected map")?
        .iter()
        .filter(|(k, _)| k == &key);
    let value = &values.next().context("missing CBOR field")?.1;
    ensure!(values.next().is_none(), "duplicate CBOR field");
    Ok(value)
}
fn blob(v: &V) -> Result<&[u8]> {
    Ok(v.as_bytes().context("expected byte string")?)
}
fn engagement(mut data: &[u8]) -> Result<&[u8]> {
    let mut first = true;
    let mut payload = None;
    loop {
        let [flags, tlen, ..] = *data else {
            anyhow::bail!("truncated NDEF header")
        };
        ensure!(
            (flags & 0x80 != 0) == first && flags & 0x20 == 0,
            "invalid NDEF record"
        );
        first = false;
        data = &data[2..];
        let size = if flags & 0x10 != 0 {
            let (&n, rest) = data.split_first().context("NDEF size")?;
            data = rest;
            n as usize
        } else {
            let n = u32::from_be_bytes(data.get(..4).context("NDEF length")?.try_into()?);
            data = &data[4..];
            n as usize
        };
        let ids = if flags & 8 != 0 {
            let (&n, rest) = data.split_first().context("NDEF ID length")?;
            data = rest;
            n as usize
        } else {
            0
        };
        let name = data.get(..tlen as usize).context("truncated NDEF type")?;
        let rest = data
            .get(tlen as usize + ids..)
            .context("truncated NDEF id")?;
        let record = rest.get(..size).context("truncated NDEF payload")?;
        if flags & 7 == 4 && name == b"iso.org:18013:deviceengagement" {
            ensure!(payload.replace(record).is_none(), "duplicate engagement");
        }
        data = &rest[size..];
        if flags & 0x40 != 0 {
            ensure!(data.is_empty(), "trailing NDEF record");
            break;
        }
    }
    payload.context("missing device engagement")
}

pub(super) fn enroll(
    card: &mut impl Card,
    channel: &mut Channel,
    home: &Home,
    secret: [u8; 32],
) -> Result<(String, Endpoint)> {
    let mailbox = [vec![0], fields(&[(0x8e, &fields(&[(0xc0, &secret)]))])].concat();
    let wrapped = channel.seal(&mailbox);
    let reply = command(card, [0x84, 0xc9, 0, 0], &wrapped, Some(0))?;
    channel.open(&reply)?;
    command(card, [0x80, 0x3c, 0x40, 0xa0], &[], None)?;
    select(card, 2)?;
    let handover = hex::decode(HANDOVER)?;
    let reply = command(
        card,
        [0, 0xc3, 0, 1],
        &fields(&[(0x53, &handover)]),
        Some(0),
    )?;
    let tags = parse(&reply)?;
    let device = field(&tags, 0x53)?;
    let engagement = engagement(device)?;
    decode(engagement)?;
    let transcript = V::Array(vec![
        tagged(engagement),
        V::Array(vec![bytes(device), bytes(&handover)]),
    ]);
    let salt = Sha256::digest(serialize(&tagged(&serialize(&transcript)?))?);
    let items = map(vec![
        ("docType", DOC.into()),
        (
            "nameSpaces",
            map(vec![(
                "com.apple.HomeKit",
                map(vec![("credential_id", false.into())]),
            )]),
        ),
    ]);
    let request = map(vec![
        ("version", "1.0".into()),
        (
            "docRequests",
            V::Array(vec![map(vec![(
                "itemsRequest",
                tagged(&serialize(&items)?),
            )])]),
        ),
    ]);
    let outgoing = Aes128Gcm::new(&derive::<16>(&secret, Some(&salt), b"SKReader").into());
    let mut nonce = [0; 12];
    nonce[11] = 1;
    let encrypted = outgoing
        .encrypt((&nonce).into(), serialize(&request)?.as_slice())
        .map_err(|_| anyhow::anyhow!("attestation encryption failed"))?;
    let envelope = fields(&[(0x53, &serialize(&map(vec![("data", V::Bytes(encrypted))]))?)]);
    let reply = command(card, [0, 0xc3, 0, 0], &envelope, Some(0))?;
    let container = decode(field(&parse(&reply)?, 0x53)?)?;
    nonce[7] = 1;
    let incoming = Aes128Gcm::new(&derive::<16>(&secret, Some(&salt), b"SKDevice").into());
    let plain = incoming
        .decrypt((&nonce).into(), blob(lookup(&container, "data".into())?)?)
        .map_err(|_| anyhow::anyhow!("invalid attestation ciphertext"))?;
    verify(&decode(&plain)?, home)
}

/// Recover signed validity bounds for credentials enrolled over NFC by Python.
pub(crate) fn legacy_validity(
    payload: &str,
    home: &Home,
    issuer: &str,
    public_key: &str,
) -> Result<Option<(i64, i64)>> {
    use base64::{engine::general_purpose::STANDARD, Engine};
    let (signer, endpoint) = verify(&decode(&STANDARD.decode(payload)?)?, home)?;
    ensure!(
        signer == issuer && endpoint.public_key == public_key,
        "legacy attestation identity mismatch"
    );
    Ok(endpoint.validity)
}

fn verify(doc: &V, home: &Home) -> Result<(String, Endpoint)> {
    let docs = lookup(doc, "documents".into())?
        .as_array()
        .context("missing documents")?;
    ensure!(docs.len() == 1, "unexpected document count");
    let issuer_signed = lookup(&docs[0], "issuerSigned".into())?;
    let cose = lookup(issuer_signed, "issuerAuth".into())?;
    let cose = if let V::Tag(18, inner) = cose {
        inner.as_ref()
    } else {
        cose
    };
    let [hdr, unprotected, payload, sig] = cose.as_array().context("invalid COSE")?.as_slice()
    else {
        anyhow::bail!("invalid COSE signature")
    };
    let protected = decode(blob(hdr)?)?;
    ensure!(
        *lookup(&protected, 1.into())? == V::from(-8),
        "expected EdDSA issuer signature"
    );
    let issuer = hex::encode(blob(lookup(unprotected, 4.into())?)?);
    let public = &home
        .issuers
        .get(&issuer)
        .context("issuer is not paired")?
        .public_key;
    let signed = serialize(&V::Array(vec![
        "Signature1".into(),
        hdr.clone(),
        bytes(&[]),
        payload.clone(),
    ]))?;
    VerifyingKey::from_bytes(&fixed::<32>(public)?)?
        .verify_strict(&signed, &Signature::from_slice(blob(sig)?)?)?;
    let V::Tag(24, wrapped) = decode(blob(payload)?)? else {
        anyhow::bail!("missing signed MSO")
    };
    let mso = decode(blob(&wrapped)?)?;
    ensure!(
        lookup(&mso, "docType".into())?.as_text() == Some(DOC),
        "unexpected credential type"
    );
    let validity = if let Some(validity) = mso
        .as_map()
        .and_then(|m| m.iter().find(|(k, _)| k.as_text() == Some("validityInfo")))
        .map(|x| &x.1)
    {
        let instant = |key: &str| -> Result<_> {
            let V::Tag(0, t) = lookup(validity, key.into())? else {
                anyhow::bail!("invalid validity time")
            };
            Ok(time::OffsetDateTime::parse(
                t.as_text().context("invalid date")?,
                &time::format_description::well_known::Rfc3339,
            )?)
        };
        Some((
            instant("validFrom")?.unix_timestamp(),
            instant("validUntil")?.unix_timestamp(),
        ))
    } else {
        None
    };
    let key = lookup(lookup(&mso, "deviceKeyInfo".into())?, "deviceKey".into())?;
    ensure!(
        *lookup(key, 1.into())? == V::from(2) && *lookup(key, (-1).into())? == V::from(1),
        "expected a P-256 key"
    );
    let x = blob(lookup(key, (-2).into())?)?;
    let y = blob(lookup(key, (-3).into())?)?;
    ensure!(
        x.len() == 32 && y.len() == 32,
        "invalid credential coordinates"
    );
    let pk = [&[4][..], x, y].concat();
    p256::PublicKey::from_sec1_bytes(&pk)?;
    Ok((
        issuer,
        Endpoint {
            validity,
            public_key: hex::encode(pk),
            persistent_key: String::new(),
            counter: 0,
            last_used_at: 0,
            enrollments: Enrollments::attested(time::OffsetDateTime::now_utc().unix_timestamp()),
        },
    ))
}
