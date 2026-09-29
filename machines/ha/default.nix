{
  lib,
  currentSystemName,
  modulesPath,
  ...
}: {
  imports = [
    ./disko-config.nix
    ../../common/linux/zfs-impermanence.nix
    ../../services/home-assistant.nix
    ../../services/homebridge.nix
    ../../services/paseo.nix
    ../../services/samba.nix
    ../../services/zigbee2mqtt.nix
  ];

  system.stateVersion = "25.05";

  # boot via systemd-boot
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 120;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = currentSystemName;
  networking.hostId = "befff1e1";

  # Enable auto gc
  nix.gc.automatic = true;

  # ===== Hacky config for some HAP thing I don't want to fully codify yet ===== #
  # HAP advertising port
  networking.firewall.allowedTCPPorts = [51926];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 60000;
      to = 61000;
    }
  ];

  # Avahi to enable HAP discovery
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.nssmdns4 = true;
  services.avahi.nssmdns6 = true;

  # Enable linger so systemd user units start at boot
  users.users.jbo.linger = true;

  # A backstop for all user work, including interactive tmux scopes that are
  # outside swarm.service. Swarm has its own smaller limit below.
  systemd.slices.user.sliceConfig = {
    CPUQuota = "250%";
    MemoryHigh = "8G";
    MemoryMax = "10G";
  };

  # swarm's unit lives in jbo's home directory. Add limits as a drop-in so
  # they apply without replacing its unit or release override.
  systemd.user.units."swarm.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      CPUQuota=150%
      MemoryHigh=4G
      MemoryMax=6G
    '';
  };
}
