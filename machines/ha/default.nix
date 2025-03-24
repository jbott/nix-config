{
  lib,
  currentSystemName,
  modulesPath,
  ...
}: {
  imports = [
    ./disko-config.nix
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

  # source: https://grahamc.com/blog/erase-your-darlings
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

  # Set noop scheduler for zfs partitions
  # source: https://github.com/cole-h/nixos-config/blob/3589d53515921772867065150c6b5a500a5b9a6b/hosts/scadrial/modules/services.nix#L70
  services.udev.extraRules = ''
    KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  '';

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
