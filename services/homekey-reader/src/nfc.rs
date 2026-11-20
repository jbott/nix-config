//! PN532 HSU framing and the Apple Enhanced Contactless Polling sequence.
use anyhow::{bail, ensure, Context, Result};
use pn532::{
    requests::{BorrowedRequest, Command},
    serialport::SerialPortInterface,
    Pn532,
};

use std::{io::Read, path::Path, thread, time::Duration};

#[cfg(test)]
const ACK: [u8; 6] = [0, 0, 0xff, 0, 0xff, 0];
const MAX_FRAME: usize = 265; // PN532 user manual, maximum TFI + command + data
const MAX_APDU: usize = 8192;

fn checksum(bytes: &[u8]) -> u8 {
    0u8.wrapping_sub(bytes.iter().fold(0u8, |a, b| a.wrapping_add(*b)))
}

#[cfg(test)]
fn frame(data: &[u8]) -> Result<Vec<u8>> {
    ensure!(
        (2..=MAX_FRAME).contains(&data.len()),
        "invalid PN532 frame size"
    );
    let mut buf = vec![0, 0, 0xff];
    if data.len() <= 255 {
        let len = data.len() as u8;
        buf.extend([len, len.wrapping_neg()]);
    } else {
        let len = (data.len() as u16).to_be_bytes();
        buf.extend([255, 255, len[0], len[1], checksum(&len)]);
    }
    buf.extend(data);
    buf.extend([checksum(data), 0]);
    Ok(buf)
}

fn response(reader: &mut impl Read, cmd: Command) -> Result<Vec<u8>> {
    let mut header = [0; 5];
    reader.read_exact(&mut header)?;
    ensure!(header[..3] == [0, 0, 255], "invalid PN532 preamble");
    let length = if header[3..] == [255, 255] {
        let mut size = [0; 3];
        reader.read_exact(&mut size)?;
        ensure!(checksum(&size) == 0, "invalid extended frame length");
        u16::from_be_bytes([size[0], size[1]]) as usize
    } else {
        ensure!(checksum(&header[3..]) == 0, "invalid frame length");
        header[3] as usize
    };
    ensure!((2..=MAX_FRAME).contains(&length), "invalid response length");
    let mut data = vec![0; length + 2];
    reader.read_exact(&mut data)?;
    ensure!(
        data[length + 1] == 0 && checksum(&data[..=length]) == 0,
        "invalid frame checksum"
    );
    ensure!(
        data[0] == 0xd5 && data[1] == cmd as u8 + 1,
        "unexpected PN532 response"
    );
    Ok(data[2..length].to_vec())
}

pub struct Reader(Pn532<SerialPortInterface, (), 272>);

impl Reader {
    pub fn open(path: &Path) -> Result<Self> {
        let port = serialport::new(path.to_string_lossy(), 115200)
            .timeout(Duration::from_millis(1200))
            .open()
            .context("opening PN532 UART")?;
        Self::initialize(port)
    }

    fn initialize(port: Box<dyn serialport::SerialPort>) -> Result<Self> {
        port.clear(serialport::ClearBuffer::All)?;
        let mut interface = SerialPortInterface { port };
        interface.send_wakeup_message()?;
        thread::sleep(Duration::from_millis(10));
        let mut reader = Reader(Pn532::new_async(interface));
        reader.command(Command::SAMConfiguration, &[1, 0, 0])?;
        let fw = reader.command(Command::GetFirmwareVersion, &[])?;
        ensure!(fw.first() == Some(&0x32), "unexpected NFC controller");
        // Use the firmware ISO-DEP initiator, including automatic RATS.
        reader.command(Command::SetParameters, &[0x14])?;
        reader.command(Command::RFConfiguration, &[5, 0xff, 1, 0])?;
        reader.command(Command::RFConfiguration, &[2, 0x0a, 0x0b, 8])?;
        Ok(reader)
    }

    fn command(&mut self, cmd: Command, args: &[u8]) -> Result<Vec<u8>> {
        // Long APDUs are split into InDataExchange requests below. The crate
        // can therefore serialize every outbound command as a normal frame.
        ensure!(args.len() <= 253, "PN532 command too large");
        self.0
            .send(BorrowedRequest::new(cmd, args))
            .map_err(|e| anyhow::anyhow!("PN532 send: {e:?}"))?;
        self.0
            .receive_ack()
            .map_err(|e| anyhow::anyhow!("PN532 ACK: {e:?}"))?;
        response(&mut self.0.interface.port, cmd)
    }

    pub fn poll(&mut self, group: &[u8; 8], express: bool) -> Result<Option<u8>> {
        self.command(Command::RFConfiguration, &[1, 2])?; // Mute the field between polling cycles.
        let found = self.command(Command::InListPassiveTarget, &[1, 0])?;
        match found.as_slice() {
            [0] => {
                self.command(Command::WriteRegister, &[0x63, 0x3d, 0])?; // CIU_BitFraming
                let ack = self.command(Command::InCommunicateThru, &ecp(group, express))?;
                ensure!(matches!(ack.first(), Some(0 | 1)), "ECP broadcast failed");
                self.command(Command::RFConfiguration, &[1, 2])?;
                Ok(None)
            }
            [1, target, _, _, sak, ..] if sak & 0x20 != 0 => Ok(Some(*target)),
            [1, target, ..] => {
                self.release(*target)?;
                Ok(None)
            }
            _ => bail!("invalid Type A poll response"),
        }
    }

    /// Firmware presence detection sends the ISO-DEP presence check without
    /// reselecting the applet. Require two misses to rearm the trigger.
    pub fn wait_for_removal(&mut self) -> Result<()> {
        let mut misses = 0;
        while misses < 2 {
            thread::sleep(Duration::from_millis(250));
            let status = self.command(Command::Diagnose, &[6])?;
            match status.as_slice() {
                [0] => misses = 0,
                [1 | 0x29 | 0x2b] => misses += 1,
                _ => bail!("invalid presence status"),
            }
        }
        Ok(())
    }

    pub fn release(&mut self, target: u8) -> Result<()> {
        self.command(Command::InRelease, &[target])?;
        Ok(())
    }

    pub fn exchange(&mut self, target: u8, apdu: &[u8]) -> Result<Vec<u8>> {
        ensure!(
            apdu.len() <= MAX_APDU && !apdu.is_empty(),
            "invalid APDU size"
        );
        let chunks = apdu.chunks(240);
        let total = chunks.len();
        let mut reply = Vec::new();
        for (i, chunk) in chunks.enumerate() {
            let mut args = vec![if i + 1 < total { target | 0x40 } else { target }];
            args.extend(chunk);
            loop {
                let part = self.command(Command::InDataExchange, &args)?;
                let (&status, body) = part.split_first().context("missing exchange status")?;
                ensure!(status & 0x3f == 0, "ISO-DEP exchange failed");
                ensure!(
                    reply.len() + body.len() <= MAX_APDU,
                    "APDU response too large"
                );
                reply.extend(body);
                if status & 0x40 == 0 {
                    break;
                }
                ensure!(!body.is_empty(), "empty PN532 continuation");
                args = vec![target];
            }
        }
        Ok(reply)
    }
}

fn ecp(group: &[u8; 8], express: bool) -> Vec<u8> {
    let mut data = vec![0x6a, 2, if express { 0xcb } else { 0x8b }, 2, 6, 2, 0x11, 0];
    data.extend(group);
    let mut crc = 0x6363u16;
    for b in &data {
        let x = *b ^ crc as u8;
        let x = x ^ (x << 4);
        crc = (crc >> 8) ^ ((x as u16) << 8) ^ ((x as u16) << 3) ^ ((x as u16) >> 4);
    }
    data.extend(crc.to_le_bytes());
    data
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_variable_and_extended_frames_without_consuming_the_next_frame() {
        for n in [1, 253, 254, 263] {
            let mut data = vec![0xd5, 0x4b];
            data.resize(n + 2, 0x55);
            let mut wire = frame(&data).unwrap();
            wire.extend(ACK);
            let mut input = &wire[..];
            assert_eq!(
                response(&mut input, Command::InListPassiveTarget).unwrap(),
                data[2..]
            );
            assert_eq!(input, ACK);
            wire[5] ^= 1;
            assert!(response(&mut &wire[..], Command::InListPassiveTarget).is_err());
        }
    }
}

#[cfg(test)]
mod serial_tests {
    use super::*;
    use serialport::{SerialPort, TTYPort};
    use std::io::Write;
    #[test]
    fn exercises_the_uart_from_wakeup_through_card_removal() -> Result<()> {
        let (mut peer, mut uart) = TTYPort::pair()?;
        peer.set_timeout(Duration::from_secs(3))?;
        uart.set_timeout(Duration::from_secs(2))?;
        let (done, finish) = std::sync::mpsc::channel();
        let (muted, idle) = std::sync::mpsc::channel();
        let device = thread::spawn(move || -> Result<()> {
            let mut wake = [0; 16];
            peer.read_exact(&mut wake)?;
            ensure!(wake[..2] == [0x55, 0x55], "bad wakeup");
            let mut poll = 0;
            let mut present = 0;
            let mut after_broadcast = false;
            loop {
                let mut head = [0; 5];
                peer.read_exact(&mut head)?;
                ensure!(
                    head[..3] == [0, 0, 255] && checksum(&head[3..]) == 0,
                    "bad header"
                );
                let mut data = vec![0; head[3] as usize + 2];
                peer.read_exact(&mut data)?;
                ensure!(checksum(&data) == 0 && data[0] == 0xd4, "bad request");
                let cmd = data[1];
                let args = &data[2..data.len() - 2];
                if after_broadcast {
                    assert_eq!((cmd, args), (0x32, &[1, 2][..]));
                    muted.send(())?;
                    after_broadcast = false;
                }
                let payload = match cmd {
                    0x14 | 0x12 | 0x32 | 0x08 => vec![],
                    0x02 => vec![0x32, 1, 6, 7],
                    0x4a => {
                        poll += 1;
                        if poll == 1 {
                            vec![0]
                        } else {
                            vec![1, 1, 0, 4, 0x20, 4, 1, 2, 3, 4, 2, 0x75]
                        }
                    }
                    0x42 => {
                        after_broadcast = true;
                        assert_eq!(hex::encode(args), "6a02cb02060211000001020304050607c851");
                        vec![1]
                    }
                    0x40 => {
                        assert_eq!(args, [1, 0, 0xa4, 4, 0]);
                        let mut v = vec![0; 254];
                        v.extend([0x90, 0]);
                        v
                    }
                    0x00 => {
                        assert_eq!(args, [6]);
                        present += 1;
                        vec![if present == 1 { 0 } else { 1 }]
                    }
                    0x52 => vec![0],
                    _ => bail!("unexpected command"),
                };
                peer.write_all(&ACK)?;
                let reply = [vec![0xd5, cmd + 1], payload].concat();
                // USB UART reads may split an extended header from its payload.
                let reply = frame(&reply)?;
                peer.write_all(&reply[..5])?;
                peer.write_all(&reply[5..])?;
                if cmd == 0x52 {
                    break;
                }
            }
            let _ = finish.recv_timeout(Duration::from_secs(2));
            Ok(())
        });
        let mut r = Reader::initialize(Box::new(uart))?;
        let group = [0, 1, 2, 3, 4, 5, 6, 7];
        assert!(r.poll(&group, true)?.is_none());
        idle.try_recv()
            .context("RF field remained on after empty poll")?;
        let target = r.poll(&group, true)?.unwrap();
        assert!(r.exchange(target, &[0, 0xa4, 4, 0])?.ends_with(&[0x90, 0]));
        r.wait_for_removal()?;
        r.release(target)?;
        done.send(())?;
        device.join().unwrap()
    }
}
