use crate::state::{endpoint_id, fixed, key_id, random, Endpoint, Enrollments, HapGrant, State};
use anyhow::{ensure, Context, Result};
use hap_tlv8::{Tlv8Map, Tlv8Writer};

pub(super) fn tlv(items: &[(u8, &[u8])]) -> Vec<u8> {
    let mut b = Vec::new();
    let mut w = Tlv8Writer::new(&mut b);
    for &(tag, v) in items {
        w.push(tag, v);
    }
    b
}
fn required(m: &Tlv8Map, tag: u8) -> Result<&[u8]> {
    m.get(tag).context("missing provisioning field")
}
pub fn control(s: &mut State, controller: &str, input: &[u8]) -> Result<Vec<u8>> {
    let request = Tlv8Map::parse(input)?;
    let op = request.get_u8(1)?.context("missing operation")?;
    ensure!((1..=3).contains(&op), "unsupported operation");
    let peer = s
        .hap
        .controllers
        .get(controller)
        .context("unpaired controller")?;
    let admin = peer.admin;
    if let Some(reader) = request.get(6) {
        ensure!(
            request.get(4).is_none() && (op == 1 || admin),
            "reader provisioning requires an administrator"
        );
        let item = Tlv8Map::parse(reader)?;
        let current = s.home.reader().ok().map(|(_, id)| id[..8].to_vec());
        if op == 1 && current.is_none() {
            return Ok(Vec::new());
        }
        let result = match op {
            1 => current
                .map(|id| tlv(&[(1, &id)]))
                .unwrap_or_else(|| tlv(&[(2, &[3])])),
            2 => {
                ensure!(
                    item.get_u8(1)?.is_none_or(|k| k == 2),
                    "invalid reader key type"
                );
                let secret = required(&item, 2)?;
                p256::SecretKey::from_slice(secret)?;
                ensure!(
                    secret.len() == 32 && required(&item, 3)?.len() == 8,
                    "invalid reader identity"
                );
                let id = hex::encode(required(&item, 3)?);
                let key = hex::encode(secret);
                let duplicate = s.home.reader_private_key == key && s.home.reader_identifier == id;
                if !duplicate {
                    for i in s.home.issuers.values_mut() {
                        i.endpoints.clear()
                    }
                    s.home.reader_private_key = key;
                    s.home.reader_identifier = id;
                }
                tlv(&[(2, &[if duplicate { 2 } else { 0 }])])
            }
            _ => {
                let found = current.as_deref() == Some(required(&item, 4)?);
                if found {
                    s.home.reader_private_key.clear();
                    s.home.reader_identifier.clear();
                    for i in s.home.issuers.values_mut() {
                        i.endpoints.clear();
                    }
                }
                tlv(&[(2, &[if found { 0 } else { 3 }])])
            }
        };
        return Ok(tlv(&[(7, &result)]));
    }
    let raw = required(&request, 4)?;
    let item = Tlv8Map::parse(raw)?;
    let id = if let Some(raw) = item.get(2) {
        ensure!(raw.len() == 64, "invalid device key length");
        let pk = [&[4][..], raw].concat();
        p256::PublicKey::from_sec1_bytes(&pk)?;
        endpoint_id(&pk)
    } else {
        let id = required(&item, 5)?;
        ensure!(id.len() == 6, "invalid endpoint identifier");
        hex::encode(id)
    };
    let missing = || tlv(&[(5, &tlv(&[(3, &[3])]))]);
    let issuer = if let Some(raw) = item.get(3) {
        ensure!(raw.len() == 8, "invalid issuer id");
        hex::encode(raw)
    } else {
        ensure!(op != 2, "adding a device requires an issuer");
        let Some((issuer, _)) = s
            .home
            .issuers
            .iter()
            .find(|(_, i)| i.endpoints.contains_key(&id))
        else {
            return Ok(missing());
        };
        issuer.clone()
    };
    ensure!(
        admin || issuer == hex::encode(key_id(&fixed::<32>(&peer.public_key)?)),
        "issuer does not belong to controller"
    );
    let Some(owner) = s.home.issuers.get_mut(&issuer) else {
        return Ok(missing());
    };
    let revocation = format!("{issuer}/{id}");
    let status = match op {
        1 => {
            if owner.endpoints.contains_key(&id) {
                0
            } else {
                3
            }
        }
        2 => {
            ensure!(
                item.get_u8(1)?.is_none_or(|k| k == 2),
                "unsupported credential type"
            );
            let raw_key = required(&item, 2)?;
            let pk = [&[4][..], raw_key].concat();
            if item.get_u8(4)? == Some(0) {
                owner.endpoints.remove(&id);
                s.home.revoked.insert(revocation);
                0
            } else {
                ensure!(item.get_u8(4)?.is_none_or(|x| x == 1), "invalid key state");
                if let Some(endpoint) = owner.endpoints.get_mut(&id) {
                    endpoint.validity = None;
                    endpoint.enrollments.hap = Some(HapGrant::from_tlv(raw));
                    2
                } else if owner.endpoints.len() >= 16 {
                    1
                } else {
                    let endpoint = Endpoint {
                        validity: None,
                        public_key: hex::encode(pk),
                        persistent_key: hex::encode(random::<32>()),
                        counter: 0,
                        last_used_at: 0,
                        enrollments: Enrollments::provisioned(HapGrant::from_tlv(raw)),
                    };
                    owner.endpoints.insert(id.clone(), endpoint);
                    s.home.revoked.remove(&revocation);
                    0
                }
            }
        }
        _ => {
            if owner.endpoints.remove(&id).is_some() {
                s.home.revoked.insert(revocation);
                0
            } else {
                3
            }
        }
    };
    let response = match op {
        1 if status == 0 => tlv(&[(1, &hex::decode(id)?)]),
        2 => tlv(&[(2, &hex::decode(issuer)?), (3, &[status])]),
        _ => tlv(&[(3, &[status])]),
    };
    Ok(tlv(&[(5, &response)]))
}
