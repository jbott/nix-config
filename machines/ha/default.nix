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

  # Avahi to enable HAP discovery
  services.avahi.enable = true;
  services.avahi.publish.enable = true;

  # Enable linger so systemd user units start at boot
  users.users.jbo.linger = true;
}
