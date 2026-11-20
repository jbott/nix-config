use anyhow::{ensure, Context, Result};
use serde::{Deserialize, Deserializer, Serialize};
use std::{collections::BTreeMap, fs::File, path::Path};

#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub struct Accessory {
    pub mac: String,
    pub private_key: String,
    pub public_key: String,
    pub config_version: u16,
}

#[derive(Clone, PartialEq)]
pub struct Controller {
    pub public_key: String,
    pub admin: bool,
    wire_id: Option<Vec<u8>>,
}

impl Controller {
    pub fn wire_id<'a>(&'a self, canonical: &'a str) -> &'a [u8] {
        self.wire_id.as_deref().unwrap_or(canonical.as_bytes())
    }
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(try_from = "StoredIdentity", into = "StoredIdentity")]
pub struct Identity {
    pub accessory: Accessory,
    pub controllers: BTreeMap<String, Controller>,
}

impl Identity {
    pub(super) fn import(path: &Path) -> Result<Self> {
        let stored: StoredIdentity = serde_json::from_reader(File::open(path)?)?;
        stored.into_identity(true)
    }

    pub fn controller_id(&self, wire_id: &[u8]) -> Option<&String> {
        self.controllers
            .iter()
            .find(|(id, c)| c.wire_id(id) == wire_id)
            .map(|(id, _)| id)
    }

    pub fn paired_key(&self, id: &str, key: &str) -> Option<&Controller> {
        self.controllers.get(id).filter(|c| c.public_key == key)
    }

    pub fn add_controller(&mut self, id: &str, key: &[u8; 32], permissions: u8) -> Result<()> {
        ensure!(
            !id.is_empty() && id.len() <= 64 && id.is_ascii() && permissions <= 1,
            "invalid controller"
        );
        let canonical = self
            .controller_id(id.as_bytes())
            .cloned()
            .unwrap_or_else(|| id.to_owned());
        let public_key = hex::encode(key);
        let admin = permissions == 1;
        if let Some(controller) = self.controllers.get_mut(&canonical) {
            ensure!(
                controller.public_key == public_key,
                "cannot replace a controller key"
            );
            controller.admin = admin;
        } else {
            ensure!(self.controllers.len() < 16, "too many controllers");
            self.controllers.insert(
                canonical,
                Controller {
                    public_key,
                    admin,
                    wire_id: None,
                },
            );
        }
        Ok(())
    }
}

// Python and version-one Rust state store the fields of a controller in three maps.
#[derive(Serialize, Deserialize)]
struct StoredIdentity {
    #[serde(flatten)]
    accessory: Accessory,
    paired_clients: BTreeMap<String, String>,
    #[serde(default, deserialize_with = "present_properties")]
    client_properties: Option<BTreeMap<String, Properties>>,
    #[serde(default)]
    client_uuid_to_bytes: BTreeMap<String, String>,
}

#[derive(Serialize, Deserialize)]
struct Properties {
    permissions: u8,
}

// Only an absent field identifies the old Python format. Explicit null is malformed.
fn present_properties<'de, D: Deserializer<'de>>(
    d: D,
) -> Result<Option<BTreeMap<String, Properties>>, D::Error> {
    BTreeMap::deserialize(d).map(Some)
}

impl StoredIdentity {
    fn into_identity(mut self, legacy_import: bool) -> Result<Identity> {
        let mut controllers = BTreeMap::new();
        for (id, public_key) in self.paired_clients {
            let admin = match &self.client_properties {
                None if legacy_import => true,
                properties => {
                    let p = properties
                        .as_ref()
                        .and_then(|m| m.get(&id))
                        .context("missing controller permissions")?;
                    ensure!(p.permissions <= 1, "invalid controller permissions");
                    p.permissions == 1
                }
            };
            // Version one falls back to the canonical ID for an unusable alias.
            let wire_id = self
                .client_uuid_to_bytes
                .remove(&id)
                .and_then(|s| hex::decode(s).ok());
            controllers.insert(
                id,
                Controller {
                    public_key,
                    admin,
                    wire_id,
                },
            );
        }
        Ok(Identity {
            accessory: self.accessory,
            controllers,
        })
    }
}

impl TryFrom<StoredIdentity> for Identity {
    type Error = anyhow::Error;

    fn try_from(stored: StoredIdentity) -> Result<Self> {
        stored.into_identity(false)
    }
}

impl From<Identity> for StoredIdentity {
    fn from(identity: Identity) -> Self {
        let mut paired_clients = BTreeMap::new();
        let mut client_properties = BTreeMap::new();
        let mut client_uuid_to_bytes = BTreeMap::new();
        for (id, controller) in identity.controllers {
            if let Some(bytes) = controller.wire_id {
                client_uuid_to_bytes.insert(id.clone(), hex::encode(bytes));
            }
            client_properties.insert(
                id.clone(),
                Properties {
                    permissions: u8::from(controller.admin),
                },
            );
            paired_clients.insert(id, controller.public_key);
        }
        Self {
            accessory: identity.accessory,
            paired_clients,
            client_properties: Some(client_properties),
            client_uuid_to_bytes,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};

    // Construct the original format independently of Identity's serializer.
    fn stored() -> Value {
        json!({
            "mac": "02:00:00:00:00:01", "config_version": 1,
            "private_key": "01".repeat(32), "public_key": "02".repeat(32),
            "paired_clients": {"canonical": "03".repeat(32), "guest": "04".repeat(32)},
            "client_properties": {"canonical": {"permissions": 1}, "guest": {"permissions": 0}},
            "client_uuid_to_bytes": {"canonical": hex::encode("wire-id")}
        })
    }

    #[test]
    fn v1_controller_records_round_trip_with_roles_and_wire_ids() -> Result<()> {
        let disk = stored();
        let mut state: Identity = serde_json::from_value(disk.clone())?;
        assert_eq!(
            state.controller_id(b"wire-id").map(String::as_str),
            Some("canonical")
        );
        assert_eq!(
            state.controller_id(b"guest").map(String::as_str),
            Some("guest")
        );
        assert!(state.controllers["canonical"].admin);
        assert!(!state.controllers["guest"].admin);
        assert_eq!(serde_json::to_value(&state)?, disk);
        state.add_controller("wire-id", &[3; 32], 0)?;
        assert!(!state.controllers["canonical"].admin);
        assert_eq!(state.controllers.len(), 2);
        assert_eq!(
            state.controllers["canonical"].wire_id("canonical"),
            b"wire-id"
        );
        Ok(())
    }

    #[test]
    fn only_explicit_legacy_import_defaults_missing_permissions() -> Result<()> {
        let mut disk = stored();
        disk.as_object_mut().unwrap().remove("client_properties");
        assert!(serde_json::from_value::<Identity>(disk.clone()).is_err());
        let dir = tempfile::tempdir()?;
        let path = dir.path().join("hap.state");
        std::fs::write(&path, serde_json::to_vec(&disk)?)?;
        assert!(Identity::import(&path)?
            .controllers
            .values()
            .all(|c| c.admin));
        for invalid in [
            Value::Null,
            json!({}),
            json!({"canonical":{"permissions":2}, "guest":{"permissions":0}}),
        ] {
            disk["client_properties"] = invalid;
            std::fs::write(&path, serde_json::to_vec(&disk)?)?;
            assert!(Identity::import(&path).is_err());
        }
        Ok(())
    }
}
