// SPDX-License-Identifier: MIT OR Apache-2.0

use anyhow::{ensure, Context, Result};
use ed25519_dalek::SigningKey;
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};
use sha1::Sha1;
use sha2::{Digest, Sha256};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs::File,
    path::Path,
};
mod enrollment;
mod identity;
mod store;
pub use enrollment::{Enrollments, HapGrant};
pub use identity::{Accessory, Controller, Identity};
pub use store::Store;

pub fn random<const N: usize>() -> [u8; N] {
    let mut v = [0; N];
    OsRng.fill_bytes(&mut v);
    v
}
pub fn key_id(key: &[u8]) -> [u8; 8] {
    let mut h = Sha256::new();
    h.update(b"key-identifier");
    h.update(key);
    h.finalize()[..8].try_into().unwrap()
}
pub fn endpoint_id(key: &[u8]) -> String {
    hex::encode(&Sha1::digest(key)[..6])
}
pub fn fixed<const N: usize>(s: &str) -> Result<[u8; N]> {
    let mut b = [0; N];
    hex::decode_to_slice(s, &mut b).context("invalid stored key length or encoding")?;
    Ok(b)
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub struct Endpoint {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub validity: Option<(i64, i64)>,
    pub public_key: String,
    pub persistent_key: String,
    #[serde(default)]
    pub counter: u64,
    #[serde(default)]
    pub last_used_at: u64,
    #[serde(default, deserialize_with = "Enrollments::nullable")]
    pub enrollments: Enrollments,
}
impl Endpoint {
    pub fn valid_now(&self) -> bool {
        let now = time::OffsetDateTime::now_utc().unix_timestamp();
        self.validity
            .is_none_or(|(start, end)| (start..=end).contains(&now))
    }
}
#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub struct Issuer {
    pub public_key: String,
    pub endpoints: BTreeMap<String, Endpoint>,
}
#[derive(Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Home {
    #[serde(default)]
    pub reader_private_key: String,
    #[serde(default)]
    pub reader_identifier: String,
    pub issuers: BTreeMap<String, Issuer>,
    #[serde(default)]
    pub revoked: BTreeSet<String>,
}
impl Home {
    pub fn reader(&self) -> Result<(p256::SecretKey, [u8; 16])> {
        let secret = fixed::<32>(&self.reader_private_key)?;
        let mut id = [0; 16];
        id[..8].copy_from_slice(&key_id(&secret));
        id[8..].copy_from_slice(&fixed::<8>(&self.reader_identifier)?);
        Ok((p256::SecretKey::from_slice(&secret)?, id))
    }
}
#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub struct State {
    pub version: u8,
    pub hap: Identity,
    pub home: Home,
    #[serde(default)]
    pub revision: u64,
}
impl State {
    pub fn fresh() -> Self {
        let seed = random::<32>();
        let mut mac = random::<6>();
        mac[0] = (mac[0] | 2) & 0xfe;
        Self {
            version: 1,
            revision: 0,
            home: Home::default(),
            hap: Identity {
                accessory: Accessory {
                    mac: mac.map(|b| format!("{b:02X}")).join(":"),
                    private_key: hex::encode(seed),
                    public_key: hex::encode(
                        SigningKey::from_bytes(&seed).verifying_key().to_bytes(),
                    ),
                    config_version: 1,
                },
                controllers: Default::default(),
            },
        }
    }
    pub fn import(hap: &Path, home: &Path) -> Result<Self> {
        let mut state = Self {
            version: 1,
            revision: 0,
            hap: Identity::import(hap)?,
            home: serde_json::from_reader(File::open(home)?)?,
        };
        state.hap.accessory.config_version = state
            .hap
            .accessory
            .config_version
            .checked_add(1)
            .unwrap_or(1);
        state.sync_issuers()?;
        state.reconcile_hap_grants(true)?;
        let trusted = state.home.clone();
        for (id, issuer) in &mut state.home.issuers {
            for endpoint in issuer.endpoints.values_mut() {
                if endpoint.enrollments.hap.is_none() {
                    let payload = endpoint
                        .enrollments
                        .attestation
                        .as_ref()
                        .and_then(|record| record.payload.as_deref())
                        .context("legacy endpoint has no enrollment evidence")?;
                    endpoint.validity = crate::attestation::legacy_validity(
                        payload,
                        &trusted,
                        id,
                        &endpoint.public_key,
                    )?;
                }
            }
        }
        state.validate()?;
        Ok(state)
    }
    // Apply the recorded provisioning operation even to previously migrated
    // state. An inactive HAP grant takes precedence over an attestation.
    fn reconcile_hap_grants(&mut self, legacy: bool) -> Result<bool> {
        let mut changed = false;
        for (issuer_id, issuer) in &mut self.home.issuers {
            let mut inactive = Vec::new();
            for (eid, endpoint) in &issuer.endpoints {
                if let Some(grant) = &endpoint.enrollments.hap {
                    if !grant.is_active(issuer_id, eid, &endpoint.public_key, legacy)? {
                        inactive.push(eid.clone());
                    }
                }
            }
            for eid in inactive {
                issuer.endpoints.remove(&eid);
                self.home.revoked.insert(format!("{issuer_id}/{eid}"));
                changed = true;
            }
        }
        Ok(changed)
    }
    pub fn sync_issuers(&mut self) -> Result<()> {
        let mut valid = BTreeSet::new();
        for controller in self.hap.controllers.values() {
            let key = &controller.public_key;
            let id = hex::encode(key_id(&fixed::<32>(key)?));
            valid.insert(id.clone());
            self.home.issuers.entry(id).or_insert_with(|| Issuer {
                public_key: key.clone(),
                endpoints: Default::default(),
            });
        }
        self.home.issuers.retain(|id, _| valid.contains(id));
        Ok(())
    }
    fn validate(&self) -> Result<()> {
        ensure!(self.version == 1, "unknown state version");
        let seed = fixed::<32>(&self.hap.accessory.private_key)?;
        ensure!(
            SigningKey::from_bytes(&seed).verifying_key().as_bytes()
                == &fixed::<32>(&self.hap.accessory.public_key)?,
            "inconsistent accessory identity"
        );
        ensure!(
            self.hap.accessory.config_version != 0
                && self.hap.accessory.mac.split(':').count() == 6
                && self
                    .hap
                    .accessory
                    .mac
                    .split(':')
                    .all(|s| fixed::<1>(s).is_ok()),
            "invalid accessory identity"
        );
        let mut peers = BTreeSet::new();
        let mut keys = BTreeSet::new();
        for (id, controller) in &self.hap.controllers {
            let key = &controller.public_key;
            ed25519_dalek::VerifyingKey::from_bytes(&fixed::<32>(key)?)?;
            ensure!(
                keys.insert(key) && peers.insert(controller.wire_id(id)),
                "invalid controller record"
            );
        }
        ensure!(
            keys.is_empty() || self.hap.controllers.values().any(|c| c.admin),
            "paired accessory has no admin"
        );
        ensure!(
            self.home.issuers.len() == keys.len(),
            "issuer list differs from pairings"
        );
        if !self.home.reader_private_key.is_empty()
            && self.home.reader_private_key != "00".repeat(32)
        {
            self.home.reader()?;
        }
        let mut seen = BTreeSet::new();
        for (id, issuer) in &self.home.issuers {
            ensure!(
                keys.contains(&issuer.public_key)
                    && *id == hex::encode(key_id(&fixed::<32>(&issuer.public_key)?)),
                "invalid issuer"
            );
            for (eid, ep) in &issuer.endpoints {
                let pk = hex::decode(&ep.public_key)?;
                p256::PublicKey::from_sec1_bytes(&pk)?;
                ensure!(
                    *eid == endpoint_id(&pk)
                        && seen.insert(eid)
                        && !self.home.revoked.contains(&format!("{id}/{eid}")),
                    "invalid endpoint"
                );
                fixed::<32>(&ep.persistent_key)?;
            }
        }
        Ok(())
    }
}
