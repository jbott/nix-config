use anyhow::{bail, ensure, Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use esphome_client::types::{EspHomeMessage, HelloRequest};
use snow::TransportState;
use tokio::io::{AsyncReadExt, AsyncWrite, AsyncWriteExt};
use tokio::net::TcpStream;

/// The receive buffer belongs to the connection: selecting a tap while a read
/// is pending must preserve a partial header or payload for the next read.
struct Frames {
    socket: TcpStream,
    buffered: Vec<u8>,
}
impl Frames {
    async fn next(&mut self) -> Result<Vec<u8>> {
        loop {
            if self.buffered.len() >= 3 {
                ensure!(
                    self.buffered[0] == 1,
                    "expected encrypted ESPHome transport"
                );
                let n = u16::from_be_bytes([self.buffered[1], self.buffered[2]]) as usize;
                if self.buffered.len() >= 3 + n {
                    let frame = self.buffered[3..3 + n].to_vec();
                    self.buffered.drain(..3 + n);
                    return Ok(frame);
                }
            }
            let mut chunk = [0; 2048];
            let n = self.socket.read(&mut chunk).await?;
            ensure!(n != 0, "ESPHome connection closed");
            self.buffered.extend_from_slice(&chunk[..n]);
        }
    }
}

pub(super) async fn write_frame(out: &mut (impl AsyncWrite + Unpin), body: &[u8]) -> Result<()> {
    let n = u16::try_from(body.len())?;
    let frame = [&[1][..], &n.to_be_bytes(), body].concat();
    out.write_all(&frame).await?;
    Ok(())
}

pub(super) struct Client {
    frames: Frames,
    noise: TransportState,
}
impl Client {
    pub async fn open(addr: &str, key: &str) -> Result<Self> {
        let socket = TcpStream::connect(addr).await?;
        socket.set_nodelay(true)?;
        #[cfg(target_os = "linux")]
        socket2::SockRef::from(&socket).set_tcp_user_timeout(Some(super::MAX_AGE))?;
        let mut frames = Frames {
            socket,
            buffered: Vec::new(),
        };
        let key = STANDARD.decode(key)?;
        let mut hs = snow::Builder::new("Noise_NNpsk0_25519_ChaChaPoly_SHA256".parse()?)
            .prologue(b"NoiseAPIInit\0\0")?
            .psk(0, key.as_slice().try_into()?)?
            .build_initiator()?;
        write_frame(&mut frames.socket, &[]).await?;
        let mut message = [0; 128];
        let n = hs.write_message(&[], &mut message[1..])?;
        write_frame(&mut frames.socket, &message[..n + 1]).await?;
        ensure!(
            frames.next().await?.first() == Some(&1),
            "invalid ESPHome greeting"
        );
        let response = frames.next().await?;
        let body = response
            .strip_prefix(&[0])
            .context("ESPHome handshake rejected")?;
        hs.read_message(body, &mut message)?;
        let mut client = Self {
            frames,
            noise: hs.into_transport_mode()?,
        };
        client
            .send(HelloRequest {
                client_info: "homekey-reader".into(),
                api_version_major: 1,
                api_version_minor: 10,
            })
            .await?;
        match client.recv().await? {
            EspHomeMessage::HelloResponse(hello) if hello.api_version_major == 1 => Ok(client),
            _ => bail!("incompatible ESPHome hello"),
        }
    }
    pub async fn recv(&mut self) -> Result<EspHomeMessage> {
        let frame = self.frames.next().await?;
        let mut data = vec![0; frame.len()];
        let n = self.noise.read_message(&frame, &mut data)?;
        data.truncate(n);
        ensure!(
            n >= 4 && usize::from(u16::from_be_bytes([data[2], data[3]])) == n - 4,
            "invalid ESPHome message length"
        );
        EspHomeMessage::try_from(data).map_err(|_| anyhow::anyhow!("invalid ESPHome message"))
    }
    pub async fn send(&mut self, message: impl Into<EspHomeMessage>) -> Result<()> {
        let plain: Vec<u8> = message.into().into();
        let mut cipher = vec![0; plain.len() + 16];
        let n = self.noise.write_message(&plain, &mut cipher)?;
        write_frame(&mut self.frames.socket, &cipher[..n]).await
    }
}
