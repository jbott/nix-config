use super::{endpoint_id, fixed};
use anyhow::{ensure, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use hap_tlv8::Tlv8Map;
use serde::{Deserialize, Deserializer, Serialize};
use serde_json::{Map, Value};

/// Python writes null for absent records. Older Rust state can also contain a
/// null enrollments field. Unknown metadata survives a read/write cycle.
#[derive(Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Enrollments {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hap: Option<HapGrant>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(super) attestation: Option<AttestationRecord>,
    #[serde(flatten)]
    extra: Map<String, Value>,
}

impl Enrollments {
    pub fn provisioned(grant: HapGrant) -> Self {
        Self {
            hap: Some(grant),
            ..Self::default()
        }
    }

    pub fn attested(at: i64) -> Self {
        Self {
            attestation: Some(AttestationRecord {
                at: Some(at),
                payload: None,
                extra: Map::new(),
            }),
            ..Self::default()
        }
    }

    pub(super) fn nullable<'de, D: Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        Ok(Option::<Self>::deserialize(d)?.unwrap_or_default())
    }
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub(super) struct AttestationRecord {
    #[serde(skip_serializing_if = "Option::is_none")]
    at: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(super) payload: Option<String>,
    #[serde(flatten)]
    extra: Map<String, Value>,
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub struct HapGrant {
    payload: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    at: Option<i64>,
    #[serde(flatten)]
    extra: Map<String, Value>,
}

impl HapGrant {
    pub fn from_tlv(raw: &[u8]) -> Self {
        Self {
            payload: STANDARD.encode(raw),
            at: None,
            extra: Map::new(),
        }
    }

    pub(super) fn is_active(
        &self,
        issuer: &str,
        endpoint: &str,
        public_key: &str,
        legacy: bool,
    ) -> Result<bool> {
        let bytes = STANDARD.decode(&self.payload)?;
        let request = Tlv8Map::parse(&bytes)?;
        let pk = hex::decode(public_key)?;
        ensure!(
            pk.len() == 65
                && pk[0] == 4
                && endpoint == endpoint_id(&pk)
                && request.get(2) == Some(&pk[1..])
                && request.get(3) == Some(&fixed::<8>(issuer)?[..])
                && request.get_u8(1)?.is_none_or(|t| t == 2),
            "HAP enrollment identity mismatch"
        );
        match request.get_u8(4)? {
            Some(0) => Ok(false),
            Some(1) => Ok(true),
            None if !legacy => Ok(true), // Rust allows an omitted state on an active ADD.
            _ => anyhow::bail!("ambiguous HAP enrollment state"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::Endpoint;
    use serde_json::json;

    #[test]
    fn enrollment_evidence_round_trips_in_the_version_one_format() -> Result<()> {
        let evidence = json!({
            "hap": {"at": 123, "payload": "AQI=", "metadata": [1, 2]},
            "attestation": {"at": 456, "payload": "AwQ=", "metadata": "legacy"},
            "extension": {"v": 1}
        });
        let typed: Enrollments = serde_json::from_value(evidence.clone())?;
        assert_eq!(serde_json::to_value(typed)?, evidence);
        assert_eq!(
            serde_json::to_value(Enrollments::provisioned(HapGrant::from_tlv(&[1, 2])))?,
            json!({"hap": {"payload": "AQI="}})
        );
        assert_eq!(
            serde_json::to_value(Enrollments::attested(456))?,
            json!({"attestation": {"at":456}})
        );
        assert!(serde_json::from_value::<Enrollments>(json!({"hap": {"at":123}})).is_err());
        Ok(())
    }

    #[test]
    fn missing_and_null_enrollments_load_without_creating_a_grant() -> Result<()> {
        let base = json!({"public_key":"", "persistent_key":""});
        let endpoint: Endpoint = serde_json::from_value(base.clone())?;
        assert!(endpoint.enrollments == Enrollments::default());
        for empty in [
            Value::Null,
            json!({}),
            json!({"hap":null,"attestation":null}),
        ] {
            let mut disk = base.clone();
            disk["enrollments"] = empty;
            let endpoint: Endpoint = serde_json::from_value(disk)?;
            assert!(endpoint.enrollments == Enrollments::default());
        }
        Ok(())
    }
}
