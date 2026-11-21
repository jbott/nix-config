// SPDX-License-Identifier: MIT OR Apache-2.0

use super::*;
const ISSUER: &str = "1398f62c6d1a457c51ba6a4b5f3dbd2f69fca93216218dc8997e416bd17d93ca";
const KID: &str = "227ee8f64e653d5a";
// Response and encrypted command vectors from the Python reader, using
// disposable device and issuer keys. The final ENVELOPE spans two APDUs.
struct EnrollmentCard {
    wallet: Wallet,
}
impl Card for EnrollmentCard {
    fn exchange(&mut self, cmd: &[u8]) -> Result<Vec<u8>> {
        if cmd[1] == 0xc9 {
            let expected = match self.wallet.1 {
                Flow::Fast => "84c90000380c9a3d2faded2cd06673791830b20eafc7e03eeac4b6ee89ead5f7dcef5183bf2f0ed77d000e9cb8681f5ca128d2c02f5cbc517505921d4200",
                _ => "84c9000038e7b24e0f248430a987ea5ae90123561555ab09fe5be07364228c2912a8c1571cb1cb6e17de45063e4ece9a835d4efe5b3449e8125565913e00",
            };
            assert_eq!(hex::encode(cmd), expected);
        }
        if cmd[1] == 0xc3 && cmd[3] == 0 {
            assert_eq!(hex::encode(cmd),"00c300009e53819ba1646461746158932c7bf8ea521224d3b496848e5d2499882a37cdb1d84136f0cbd990fa3e8a09f2dab9c21c5918ecaa3d2e98d5a3a33b15a5e802186e827a1f712019eadca2cc1236dce8c8f80aab5c16b67bde343e111473344764e36cfd3575ac5467d712a7f8c827d880213921e6b2a2ad92e70a16709ca6ca57298cb97efbcc06777904d6079d0c87c39b9b48dc900718c82d80330c1ba0e800");
        }
        self.wallet.exchange(cmd)
    }
}
fn presentation(issuer: &str, corrupt: bool, flow: Flow) -> Result<Authenticated> {
    let mut home = Home {
        reader_private_key: hex::encode([1; 32]),
        reader_identifier: hex::encode([2; 8]),
        ..Default::default()
    };
    home.issuers.insert(
        KID.into(),
        Issuer {
            public_key: issuer.into(),
            endpoints: Default::default(),
        },
    );
    let (auth1, ack) = if flow == Flow::Attestation {
        let endpoint = Endpoint {
            validity: None,
            public_key: PUB.into(),
            persistent_key: PERSIST.into(),
            counter: 17,
            last_used_at: 0,
            enrollments: crate::state::Enrollments::provisioned(crate::state::HapGrant::from_tlv(
                b"recorded grant",
            )),
        };
        home.issuers
            .get_mut(KID)
            .unwrap()
            .endpoints
            .insert(endpoint_id(&hex::decode(PUB)?), endpoint);
        (REQUIRED_AUTH1, "82e9412a98c1db939000")
    } else {
        (AUTH1, "b58533c4df42c0209000")
    };
    let mut end=hex::decode("984bac8138cb794290606e7d16b2eca9bc49343257085d16736052410b7a701df0fc7abb054156456445aef191482df1567352e186b40d0f73c2d4a39890231cc37e7be5fcf4d4e178677abdcf900062eaa21516f02c986d76e5f532d625775d191f94c950df3fda626a30d3c4a6faced03cf0eeefea694ed9d9fa9e3e49fb3d643c3ec84cd316d22380630aa087453d8b190dde3ba80ac6ed496ba744a3e9d03618c78cc8494d72330a03950e49b73f0b91304a3a5dd737c3ac57436d92ff27ef7b908f33aa2b3e2ce604c160d37ec85febedb6e27ef5daa8ce01c3ec47abe62a0a8ae2094fc812551f22271525876d0097cf0e7f8f6093dc84e47fd641bdaa5981017c079000")?;
    if corrupt {
        end[12] ^= 1;
    }
    let script=VecDeque::from([(0xa4,hex::decode("5c0202009000")?),(0x80,hex::decode(STANDARD)?),(0x81,hex::decode(auth1)?),
        (0xc9,hex::decode(ack)?),(0x3c,vec![0x90,0]),(0xa4,vec![0x90,0]),
        (0xc3,hex::decode("532cdc1e060469736f2e6f72673a31383031333a646576696365656e676167656d656e746d646f63a10063312e309000")?),(0xc3,hex::decode("5382014ca164646174615901432a11dc3819e376bad9b1ea1365617e0ebd39214e7f411cc767b4ffff8d62bc327b78576edaf1c4061e00d90f4749306d59ccb646a2f5377354c6ac4039a86100")?),(0xc0,end)]);
    transaction(
        &mut EnrollmentCard {
            wallet: Wallet(script, flow),
        },
        &home,
        flow,
        SecretKey::from_slice(&[3; 32])?,
        [4; 16],
        [7; 32],
    )
}
#[test]
fn enrolls_only_the_endpoint_attested_by_a_paired_issuer() {
    let authenticated = presentation(ISSUER, false, Flow::Fast).unwrap();
    assert_eq!(authenticated.issuer, KID);
    assert_eq!(authenticated.endpoint.public_key, PUB);
    assert_eq!(authenticated.endpoint.persistent_key, PERSIST);
    assert!(presentation(
        &hex::encode(
            ed25519_dalek::SigningKey::from_bytes(&[99; 32])
                .verifying_key()
                .as_bytes()
        ),
        false,
        Flow::Fast
    )
    .is_err());
    assert!(presentation(ISSUER, true, Flow::Fast).is_err());
}

#[test]
fn reattests_an_enrolled_endpoint_and_preserves_its_hap_grant() {
    let endpoint = presentation(ISSUER, false, Flow::Attestation)
        .unwrap()
        .endpoint;
    assert_eq!(endpoint.persistent_key, REQUIRED_PERSIST);
    assert_eq!(endpoint.counter, 17);
    assert!(endpoint.enrollments.hap == Some(crate::state::HapGrant::from_tlv(b"recorded grant")));
    assert!(presentation(ISSUER, true, Flow::Attestation).is_err());
}
