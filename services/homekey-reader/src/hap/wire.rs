use super::crypto::nonce_counter;
use anyhow::{bail, ensure, Context, Result};
use hap_crypto::aead::{chacha20poly1305_open, chacha20poly1305_seal};
use std::{
    io::{Read, Write},
    net::TcpStream,
};

pub(super) struct Keys {
    send: [u8; 32],
    recv: [u8; 32],
    sent: u64,
    received: u64,
}
impl Keys {
    pub fn new(send: [u8; 32], recv: [u8; 32]) -> Self {
        Self {
            send,
            recv,
            sent: 0,
            received: 0,
        }
    }
}
pub struct Wire {
    pub socket: TcpStream,
    pub(super) keys: Option<Keys>,
    buffer: Vec<u8>,
}
pub struct Request {
    pub method: String,
    pub path: String,
    pub body: Vec<u8>,
}
pub struct Reply {
    pub code: u16,
    pub mime: &'static str,
    pub bytes: Vec<u8>,
}
impl Reply {
    pub fn tlv(bytes: Vec<u8>) -> Self {
        Self {
            code: 200,
            mime: "application/pairing+tlv8",
            bytes,
        }
    }
    pub fn json(code: u16, value: serde_json::Value) -> Self {
        Self {
            code,
            mime: "application/hap+json",
            bytes: serde_json::to_vec(&value).unwrap(),
        }
    }
    pub fn empty(code: u16) -> Self {
        Self {
            code,
            mime: "application/hap+json",
            bytes: vec![],
        }
    }
}
impl Wire {
    pub fn new(socket: TcpStream) -> Self {
        Self {
            socket,
            keys: None,
            buffer: Vec::new(),
        }
    }
    pub fn upgrade(&mut self, keys: Keys) -> Result<()> {
        ensure!(
            self.buffer.is_empty(),
            "unexpected pipelined data on verify"
        );
        self.keys = Some(keys);
        Ok(())
    }
    fn receive(&mut self) -> Result<()> {
        if let Some(keys) = &mut self.keys {
            let mut len = [0; 2];
            self.socket.read_exact(&mut len)?;
            let n = u16::from_le_bytes(len) as usize;
            ensure!((1..=1024).contains(&n), "invalid session frame");
            let mut data = vec![0; n + 16];
            self.socket.read_exact(&mut data)?;
            let plain =
                chacha20poly1305_open(&keys.recv, &nonce_counter(keys.received), &len, &data)?;
            keys.received = keys.received.checked_add(1).context("session exhausted")?;
            self.buffer.extend(plain);
        } else {
            let mut chunk = [0; 2048];
            let n = self.socket.read(&mut chunk)?;
            ensure!(n > 0, "connection closed");
            self.buffer.extend(&chunk[..n]);
        }
        Ok(())
    }
    pub fn request(&mut self) -> Result<Request> {
        loop {
            let mut headers = [httparse::EMPTY_HEADER; 32];
            let mut req = httparse::Request::new(&mut headers);
            if let httparse::Status::Complete(n) = req.parse(&self.buffer)? {
                ensure!(n <= 8192, "HTTP headers too large");
                let mut length = None;
                for h in req.headers.iter() {
                    if h.name.eq_ignore_ascii_case("content-length") {
                        ensure!(length.is_none(), "duplicate length");
                        length = Some(std::str::from_utf8(h.value)?.parse::<usize>()?);
                    } else if h.name.eq_ignore_ascii_case("transfer-encoding") {
                        bail!("unsupported request encoding")
                    }
                }
                let length = length.unwrap_or(0);
                ensure!(length <= 65536, "request body too large");
                let method = req.method.context("missing method")?.to_owned();
                let path = req.path.context("missing path")?.to_owned();
                while self.buffer.len() < n + length {
                    self.receive()?
                }
                let body = self.buffer[n..n + length].to_vec();
                self.buffer.drain(..n + length);
                return Ok(Request { method, path, body });
            }
            ensure!(self.buffer.len() < 8192, "HTTP headers too large");
            self.receive()?;
        }
    }
    pub fn reply(&mut self, reply: Reply) -> Result<()> {
        let reason = match reply.code {
            200 => "OK",
            204 => "No Content",
            207 => "Multi-Status",
            400 => "Bad Request",
            404 => "Not Found",
            470 => "Connection Authorization Required",
            _ => "Error",
        };
        let mut data = format!(
            "HTTP/1.1 {} {}\r\nContent-Type: {}\r\nContent-Length: {}\r\n\r\n",
            reply.code,
            reason,
            reply.mime,
            reply.bytes.len()
        )
        .into_bytes();
        data.extend(reply.bytes);
        if let Some(keys) = &mut self.keys {
            for chunk in data.chunks(1024) {
                let len = (chunk.len() as u16).to_le_bytes();
                let ciphertext =
                    chacha20poly1305_seal(&keys.send, &nonce_counter(keys.sent), &len, chunk)?;
                keys.sent = keys.sent.checked_add(1).context("session exhausted")?;
                self.socket.write_all(&len)?;
                self.socket.write_all(&ciphertext)?;
            }
        } else {
            self.socket.write_all(&data)?
        }
        self.socket.flush()?;
        Ok(())
    }
}
