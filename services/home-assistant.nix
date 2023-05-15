{
  virtualisation.oci-containers = {
    backend = "podman";
    containers.home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:2023.5.3";
      environment = {
        TZ = "America/Los_Angeles";
      };
      volumes = [
        "/persist/var/lib/home-assistant:/config"
      ];
      extraOptions = ["--network=host"];
    };
  };

  # Enable homekit bridge on all interfaces
  networking.firewall.allowedTCPPorts = [21212];
  networking.firewall.allowedUDPPorts = [5353];

  # Enable webui on tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8123];
}
