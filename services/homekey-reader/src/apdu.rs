// SPDX-License-Identifier: Apache-2.0
// Home Key protocol port based on kormax/apple-home-key-reader. See NOTICE.

use anyhow::{bail, ensure, Context, Result};
use std::collections::BTreeMap;

pub trait Card {
    fn exchange(&mut self, apdu: &[u8]) -> Result<Vec<u8>>;
}

pub fn command(
    card: &mut impl Card,
    header: [u8; 4],
    data: &[u8],
    le: Option<u8>,
) -> Result<Vec<u8>> {
    let mut cmd = header.to_vec();
    if !data.is_empty() {
        cmd.push(data.len().try_into()?);
        cmd.extend(data);
    }
    cmd.extend(le);
    let mut result = Vec::new();
    for _ in 0..64 {
        let reply = card.exchange(&cmd)?;
        let n = reply.len().checked_sub(2).context("missing APDU status")?;
        ensure!(n + result.len() <= 16384, "APDU chain too long");
        result.extend(&reply[..n]);
        match &reply[n..] {
            [0x90, 0] => return Ok(result),
            [0x61, next] => cmd = vec![0, 0xc0, 0, 0, *next],
            _ => bail!("card rejected instruction {:02x}", header[1]),
        }
    }
    bail!("too many APDU continuations")
}

pub fn fields(items: &[(u8, &[u8])]) -> Vec<u8> {
    let mut result = Vec::new();
    for &(tag, data) in items {
        result.push(tag);
        match data.len() {
            0..=127 => result.push(data.len() as u8),
            128..=255 => result.extend([0x81, data.len() as u8]),
            _ => {
                result.push(0x82);
                result.extend((data.len() as u16).to_be_bytes())
            }
        }
        result.extend(data);
    }
    result
}
pub fn parse(mut data: &[u8]) -> Result<BTreeMap<u8, &[u8]>> {
    let mut result = BTreeMap::new();
    while !data.is_empty() {
        let (&tag, rest) = data.split_first().context("missing tag")?;
        let (&first, mut rest) = rest.split_first().context("missing length")?;
        let len = match first {
            0..=127 => first as usize,
            0x81 | 0x82 => {
                let n = (first & 0x7f) as usize;
                let digits = rest.get(..n).context("short field length")?;
                rest = &rest[n..];
                digits.iter().fold(0, |a, &b| a * 256 + b as usize)
            }
            _ => bail!("invalid field length"),
        };
        let value = rest.get(..len).context("truncated field")?;
        ensure!(result.insert(tag, value).is_none(), "duplicate field");
        data = &rest[len..];
    }
    Ok(result)
}
pub fn field<'a>(v: &BTreeMap<u8, &'a [u8]>, tag: u8) -> Result<&'a [u8]> {
    v.get(&tag).copied().context("missing required field")
}
pub fn select(card: &mut impl Card, aid: u8) -> Result<Vec<u8>> {
    command(
        card,
        [0, 0xa4, 4, 0],
        &[0xa0, 0, 0, 8, 0x58, 1, aid],
        Some(0),
    )
}
