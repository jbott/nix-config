{
  services.scrutiny = {
    enable = true;
  };

  environment.persistence."/persist".directories = [
    # scrutiny runs with DynamicUser, so its state lives under
    # /var/lib/private, which systemd requires to be 0700.
    {
      directory = "/var/lib/private";
      mode = "0700";
    }
    # SMART history; scrutiny reconnects with its default token after a reboot.
    {
      directory = "/var/lib/influxdb2";
      user = "influxdb2";
      group = "influxdb2";
    }
  ];

  # Enable webui on tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8080];
}
