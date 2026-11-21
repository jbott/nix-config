<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->

# Home Key reader

The reader runs on Linux with a PN532 in UART mode. It exposes the NFC Lock accessory over HomeKit IP, authenticates iPhone and Apple Watch Wallet presentations, and can pulse an ESPHome switch. The default action logs successful taps. A Home app write to the virtual lock keeps its state locked. Only an authenticated NFC presentation can fire the switch.

## Build and test

Run `cargo test --locked` here, or build `nix build .#homekey-reader` from the flake root. The tests use synthetic keys, a UART pair, a loopback HAP controller, and a simulated encrypted ESPHome switch. The authentication fixtures cover FAST, STANDARD and first-use attestation, including a multi-part response. The production entry point generates fresh randomness for each presentation.

The Linux device on `ha` is `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0`. Each reconnect opens that path at 115200 baud. The reader uses the `pn532` crate for UART wakeup, commands and acknowledgements. The receive path reads the length from each normal or extended frame. The polling loop broadcasts the home’s ECP identifier on a Type A polling miss and waits for target removal after a presentation.

The `services.homekey-reader.flow` setting selects the minimum proof for each tap. The default `"fast"` accepts FAST authentication for a known credential and falls back to STANDARD or issuer attestation as needed. Set `"standard"` to require a device signature on every tap, or `"attestation"` to also require a current issuer attestation each time.

## Existing installation on ha

On `ha`, edit `/persist/etc/homekey-reader/trigger.json` as root to choose the action after an authenticated tap. Run `sudo systemctl restart homekey-reader` to load changes. An ESPHome action uses the device address and switch object ID. For example:

```json
{
  "type": "esphome",
  "address": "device.local:6053",
  "entity": "relay",
  "psk_file": "/run/credentials/homekey-reader.service/esphome-psk"
}
```

For log-only operation, set the file to `{"type":"dry_run"}`. Systemd loads the action file and the ESPHome Noise key from `/persist/etc/homekey-reader/esphome-psk` at startup. The latter can point to an existing private key file. The HomeKit setup PIN comes from `/persist/secrets/homekey-setup-pin`. Keep the persistent files root-owned and mode 0600.

The reader expires queued taps after 750 ms and bounds unacknowledged TCP data on Linux. With a plain ESPHome switch a buffered command can still arrive late. Add `"receiver_expiry": true` only for a device that implements the prepare, acknowledgement and commit actions. In that mode the reader sends a fresh token, waits for the device to echo it, and sends the remaining time budget. The receiver checks that budget against its own monotonic timer and consumes the token once. Missing actions disable delivery in this mode.

Deploy with `deploy-nixos -r ha`. The HomeKit accessory keeps port 51926, its signing identity and the existing pairings and cards.

The handoff unit releases the scanner from the Python user service. Rust requires its private `/var/lib/homekey-reader/state.json`, backed by `/persist/var/lib/homekey-reader`. If that file goes missing after cutover, restore a current Rust backup before starting the reader. Automatic startup fails closed. For a deliberately authorized initial migration, stop Python, run `sudo systemctl start homekey-reader-import`, then start `homekey-reader`. Only that explicit import reads the two legacy files through systemd credentials. It refuses to overwrite existing state.

Verify the deployment with `systemctl status homekey-reader` and `journalctl -u homekey-reader -b`. The service logs `PN532 ready` and `ESPHome switch ready`. Confirm Apple Home shows the existing lock online. A physical tap then sends one switch command. In dry-run mode the service logs `authenticated Home Key (dry run)`.

For rollback, stop the Rust unit, switch to the recorded Python generation, then run `systemctl --user daemon-reload` and `systemctl --user start apple-home-key-reader` as the reader owner. Python reads its original files. A later switch to Rust resumes its separate saved state. Reconcile any new pairings or revocations before switching back to an older authorization state.

For a new accessory, create a private state directory and run `homekey-reader init STATE_DIR` as its owner. Pair it with the configured setup PIN. Keep the state directory, legacy files, and runtime credential files outside version control and the Nix store.

## License

Files marked `MIT OR Apache-2.0` may be used under either license. Files marked `Apache-2.0` include the Home Key protocol port and adapted HomeKit pairing code. Distributing the complete reader requires following the Apache-2.0 terms for those files. The [upstream notices](NOTICE) identify the source projects.

The full texts are in [MIT](LICENSES/MIT.txt) and [Apache-2.0](LICENSES/Apache-2.0.txt).
