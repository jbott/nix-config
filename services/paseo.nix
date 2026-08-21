{
  pkgs,
  lib,
  ...
}: {
  # Paseo self-hosted coding-agent daemon, run natively as jbo (un-containerized)
  # so agents execute in the real host environment: jbo's files, tools, configs
  # and credentials. The daemon is packaged from @getpaseo/cli in the overlay.

  # Expose the CLI on the host too (`paseo ls`, `paseo status`, ...).
  environment.systemPackages = [pkgs.paseo];

  # PASEO_PASSWORD stays out of the nix store. Create on the host:
  #   /persist/var/lib/paseo/paseo.env  ->  PASEO_PASSWORD=<secret>
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/paseo 0755 root root -"
  ];

  systemd.services.paseo = {
    description = "Paseo self-hosted coding-agent daemon";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "tailscaled.service"];
    wants = ["network-online.target"];

    # Toolchain the daemon hands to the agents it spawns. Running on the host as
    # jbo, we reuse the host packages directly (same store paths as jbo's
    # profile) — claude-code, jj, git, nix, node, plus a normal shell userland.
    path = [
      pkgs.paseo
      pkgs.claude-code
      pkgs.jujutsu
      pkgs.git
      pkgs.nix
      pkgs.nodejs_22
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.findutils
      pkgs.gnutar
      pkgs.gzip
      pkgs.which
      pkgs.openssh
    ];

    environment = {
      HOME = "/home/jbo";
      # Daemon state in jbo's (persisted) home; ~/.claude oauth is used as-is.
      PASEO_HOME = "/home/jbo/.paseo";
      TZ = "America/Los_Angeles";
      # Voice needs sherpa-onnx (pruned from the package); disable it. The daemon
      # loads it lazily, so this just avoids the model download / load attempt.
      PASEO_VOICE_MODE_ENABLED = "false";
      # CA bundle so claude / git-over-https reach their endpoints under systemd.
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };

    serviceConfig = {
      User = "jbo";
      WorkingDirectory = "/home/jbo";
      # PASEO_PASSWORD (read by root before dropping to User=, so 0600 is fine).
      EnvironmentFile = "/persist/var/lib/paseo/paseo.env";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.paseo}/bin/paseo daemon start"
        "--foreground"
        "--listen 0.0.0.0:6767"
        "--no-relay" # tailscale-only; no end-to-end relay
        "--web-ui"
        "--hostnames ha.tailc10a4.ts.net,ha"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Expose the daemon/web UI on tailscale only, matching scrutiny.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [6767];
}
