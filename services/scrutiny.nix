{
  services.scrutiny = {
    enable = true;
  };

  # Enable webui on tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8080];
}
