{...}: {
  services.tailscale.enable = true;

  environment.persistence."/persist".directories = ["/var/lib/tailscale"];

  # Strict reverse path filtering breaks exit node, disable it here
  networking.firewall.checkReversePath = "loose";

  # Enable forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
