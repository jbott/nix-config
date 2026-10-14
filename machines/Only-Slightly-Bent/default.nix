{
  pkgs,
  currentSystemName,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./zfs-tank.nix
    ../../common/linux/zfs-impermanence.nix
    ../../common/linux/disk-spindown.nix
    ../../common/linux/smartd.nix
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

  # Enable auto gc
  nix.gc.automatic = true;
}
