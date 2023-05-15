{pkgs, ...}: {
  services.tailscale.enable = true;

  # We need to inject --statedir, but the upstream module already uses this to
  # set the interface name, so set that here as well
  systemd.services.tailscaled.serviceConfig.Environment = [
    "FLAGS='--tun tailscale0 --state=/persist/var/lib/tailscale/tailscaled.state --statedir=/persist/var/lib/tailscale'"
  ];

  # Strict reverse path filtering breaks exit node, disable it here
  networking.firewall.checkReversePath = "loose";

  # Enable forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
