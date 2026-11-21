// SPDX-License-Identifier: Apache-2.0
// Home Key protocol port based on kormax/apple-home-key-reader. See NOTICE.

use aes::{
    cipher::{
        block_padding::Iso7816, BlockDecryptMut, BlockEncrypt, BlockEncryptMut, KeyInit, KeyIvInit,
    },
    Aes128,
};
use anyhow::{ensure, Context, Result};
use cmac::{Cmac, Mac};
use hkdf::Hkdf;
use sha2::Sha256;
use subtle::ConstantTimeEq;

pub fn derive<const N: usize>(ikm: &[u8], salt: Option<&[u8]>, info: &[u8]) -> [u8; N] {
    let mut out = [0; N];
    Hkdf::<Sha256>::new(salt, ikm)
        .expand(info, &mut out)
        .expect("fixed HKDF size");
    out
}
pub struct Channel {
    enc: [u8; 16],
    mac: [u8; 16],
    rmac: [u8; 16],
    chain: [u8; 16],
    counter: u8,
}
impl Channel {
    pub fn new(keys: [u8; 48]) -> Self {
        Self {
            enc: keys[..16].try_into().unwrap(),
            mac: keys[16..32].try_into().unwrap(),
            rmac: keys[32..].try_into().unwrap(),
            chain: [0; 16],
            counter: 0,
        }
    }
    fn iv(&self, response: bool) -> [u8; 16] {
        let mut iv = [0; 16];
        iv[0] = if response { 0x80 } else { 0 };
        iv[15] = self.counter;
        let mut block = iv.into();
        Aes128::new((&self.enc).into()).encrypt_block(&mut block);
        block.into()
    }
    fn tag(&self, key: &[u8; 16], data: &[u8]) -> [u8; 16] {
        let mut mac = <Cmac<Aes128> as Mac>::new_from_slice(key).unwrap();
        mac.update(&self.chain);
        mac.update(data);
        mac.finalize().into_bytes().into()
    }
    pub fn seal(&mut self, data: &[u8]) -> Vec<u8> {
        let mut ciphertext =
            cbc::Encryptor::<Aes128>::new((&self.enc).into(), (&self.iv(false)).into())
                .encrypt_padded_vec_mut::<Iso7816>(data);
        self.chain = self.tag(&self.mac, &ciphertext);
        ciphertext.extend(&self.chain[..8]);
        ciphertext
    }
    pub fn open(&mut self, data: &[u8]) -> Result<Vec<u8>> {
        let n = data
            .len()
            .checked_sub(8)
            .context("missing secure response MAC")?;
        let (ct, tag) = data.split_at(n);
        ensure!(
            bool::from(self.tag(&self.rmac, ct)[..8].ct_eq(tag)),
            "invalid secure response"
        );
        let clear = if ct.is_empty() {
            Vec::new()
        } else {
            cbc::Decryptor::<Aes128>::new((&self.enc).into(), (&self.iv(true)).into())
                .decrypt_padded_vec_mut::<Iso7816>(ct)
                .map_err(|_| anyhow::anyhow!("invalid response padding"))?
        };
        self.counter = self
            .counter
            .checked_add(1)
            .context("secure session exhausted")?;
        Ok(clear)
    }
}
