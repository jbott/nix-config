{pkgs, ...}: let
  imageName = "ghcr.io/getpaseo/paseo";
  imageTag = "latest";
  imageDigest = "sha256:593cb65b1eabee061af8f240fcb4031818e9c330fe66b584c345e3b296531b95";
  sha256 = "sha256-lEBsIYVOqX4SZ42kcJhIqrkmMBwQas6sMwgJQ+3FE3A=";

  image = "${imageName}:${imageTag}";
  imageFile = pkgs.dockerTools.pullImage {
    inherit imageName imageDigest sha256;
    finalImageTag = imageTag;
  };
in {
  # podman won't create bind-mount sources; the container runs as uid/gid 1000,
  # so pre-create these dirs with that ownership.
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/paseo 0755 root root -"
    "d /persist/var/lib/paseo/home 0700 1000 1000 -"
    "d /persist/var/lib/paseo/workspace 0755 1000 1000 -"
  ];

  virtualisation.oci-containers = {
    containers.paseo = {
      inherit image imageFile;
      environment = {
        TZ = "America/Los_Angeles";
        # Daemon rejects requests whose Host header isn't whitelisted (403).
        # Allow this host's tailscale MagicDNS names.
        PASEO_HOSTNAMES = "ha.tailc10a4.ts.net,ha";
        # Put the nix-built claude-code CLI (available via the /nix/store mount)
        # on PATH so the daemon can spawn `claude`; base image PATH kept after it.
        PATH = "${pkgs.claude-code}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
      };
      # PASEO_PASSWORD lives outside the nix store. Create this file on the host:
      #   /persist/var/lib/paseo/paseo.env  ->  PASEO_PASSWORD=<secret>
      environmentFiles = ["/persist/var/lib/paseo/paseo.env"];
      volumes = [
        "/persist/var/lib/paseo/home:/home/paseo" # daemon state + agent credentials
        "/persist/var/lib/paseo/workspace:/workspace" # code the agents operate on
        "/nix/store:/nix/store:ro" # closure backing the mounted claude-code CLI
        "/home/jbo/.claude:/home/paseo/.claude" # real host OAuth login + claude settings (CLAUDE_CONFIG_DIR)
        "/home/jbo/src:/home/jbo/src" # repos, mounted at their host path so absolute paths match
      ];
      extraOptions = ["--network=host"]; # binds 0.0.0.0:6767; reachable via tailscale only (firewall below)
    };
  };

  # Expose the daemon/web UI on tailscale only, matching scrutiny.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [6767];
}
