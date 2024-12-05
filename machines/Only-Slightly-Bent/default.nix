{
  lib,
  pkgs,
  currentSystemName,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./zfs-tank.nix
    ../../common/linux/disk-spindown.nix
    ../../common/linux/smartd.nix
    ../../services/home-assistant.nix
    ../../services/scrutiny.nix
  ];

  system.stateVersion = "22.11";

  # Enable binfmt_misc emulation
  environment.systemPackages = with pkgs; [qemu];
  boot.binfmt.emulatedSystems = ["aarch64-linux" "armv7l-linux"];

  # boot via systemd-boot
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 120;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = currentSystemName;
  networking.hostId = "e486d79d"; # Hardcoded for zfs

  # source: https://grahamc.com/blog/erase-your-darlings
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

  # Set noop scheduler for zfs partitions
  # source: https://github.com/cole-h/nixos-config/blob/3589d53515921772867065150c6b5a500a5b9a6b/hosts/scadrial/modules/services.nix#L70
  services.udev.extraRules = ''
    KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  '';
}
