// SPDX-License-Identifier: MIT OR Apache-2.0

use super::*;
use crate::state::Issuer;
use std::collections::VecDeque;

// Generated with kormax's reference using synthetic scalar seeds 1, 3, 5 and 6.
const PUB:&str="0407810ea974cea5773e63b897f37e3be9a09e7a5fe9b971a44d1065ac2a3a9311637e47a4f99464a0fdce44a88ec7d703a9183c1d06552d9e2d6b76069481c577";
const PERSIST: &str = "7eedc2e5ae821bc99e865da18d90da71b870d3e549473a9803bea4d64451d1a6";
const FAST:&str="864104b0514c4c13540f2397f54719f3332e7ef38e42ad9dc08b71e660ce16b9e88d094e7f3adc888e944d45d5e4594e3fbe289180bb1cd7fc55d1b5c7cb501c09ca509d10eee7425b07228cba972b1c21f4e05d1b9000";
const STANDARD:&str="864104b0514c4c13540f2397f54719f3332e7ef38e42ad9dc08b71e660ce16b9e88d094e7f3adc888e944d45d5e4594e3fbe289180bb1cd7fc55d1b5c7cb501c09ca509000";
const AUTH1:&str="ec9813591ab10d04346eadb88e257f9c747549d20c40cf2c502c8a63f7e4437064d5e50adbfcfac66cef766617ab51a6df605dd9fd2acaf0f8d829dd964c1833e8617631b06747ba6c74e49081576214abc47474d5bbbecc9000";
const REQUIRED_AUTH1: &str = "9bcf3bfcbeb139ce2a9ae74799d246d2641b60128017671e8a0045971459fd56418d5a16e8ae787d213bff5aea48b2aa986a3b85ed6642ab656134ede919462ab6828784907ae24b154f5a7aa3d2b60d9f7d8f3398d205769000";
const REQUIRED_PERSIST: &str = "b5408235a8ce7b0aa15a4cc25b5bc361977ce54accfa434e4c0191c904ee3584";
struct Wallet(VecDeque<(u8, Vec<u8>)>, Flow);
impl Card for Wallet {
    fn exchange(&mut self, cmd: &[u8]) -> Result<Vec<u8>> {
        let (ins, data) = self.0.pop_front().context("unexpected APDU")?;
        ensure!(cmd[1] == ins, "wrong APDU");
        if ins == 0x80 {
            assert_eq!(cmd[2], u8::from(self.1 == Flow::Fast));
        }
        Ok(data)
    }
}
fn run(flow: Flow, auth0: &str, auth1: Option<Vec<u8>>) -> Result<Authenticated> {
    let mut home = Home {
        reader_private_key: hex::encode([1; 32]),
        reader_identifier: hex::encode([2; 8]),
        ..Default::default()
    };
    let ep = Endpoint {
        validity: None,
        public_key: PUB.into(),
        persistent_key: PERSIST.into(),
        counter: 0,
        last_used_at: 0,
        enrollments: Default::default(),
    };
    let id = endpoint_id(&hex::decode(PUB)?);
    home.issuers.insert(
        "issuer".into(),
        Issuer {
            public_key: String::new(),
            endpoints: [(id, ep)].into(),
        },
    );
    let mut script = VecDeque::from([
        (0xa4, hex::decode("5c0202009000")?),
        (0x80, hex::decode(auth0)?),
    ]);
    if let Some(reply) = auth1 {
        script.push_back((0x81, reply));
    }
    script.push_back((0x3c, vec![0x90, 0]));
    transaction(
        &mut Wallet(script, flow),
        &home,
        flow,
        SecretKey::from_slice(&[3; 32])?,
        [4; 16],
        [7; 32],
    )
}
#[test]
fn matches_reference_fast_and_standard_transactions() {
    assert_eq!(
        run(Flow::Fast, FAST, None).unwrap().endpoint.public_key,
        PUB
    );
    assert_eq!(
        run(Flow::Fast, STANDARD, Some(hex::decode(AUTH1).unwrap()))
            .unwrap()
            .endpoint
            .persistent_key,
        PERSIST
    );
}
#[test]
fn altered_auth1_mac_fails() {
    let mut bad = hex::decode(AUTH1).unwrap();
    bad[3] ^= 1;
    assert!(run(Flow::Fast, STANDARD, Some(bad)).is_err());
}
mod enrollment;

#[test]
fn requires_the_configured_minimum_proof() {
    assert!(run(Flow::Standard, FAST, None).is_err());
    let proof = hex::decode(REQUIRED_AUTH1).unwrap();
    assert_eq!(
        run(Flow::Standard, STANDARD, Some(proof.clone()))
            .unwrap()
            .endpoint
            .persistent_key,
        REQUIRED_PERSIST
    );
    assert!(run(Flow::Attestation, STANDARD, Some(proof)).is_err());
}
