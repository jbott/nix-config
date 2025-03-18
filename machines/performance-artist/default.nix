{
  config,
  lib,
  currentSystemName,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../../services/spotifyd.nix
  ];

  system.stateVersion = "23.11";

  networking.hostName = currentSystemName;
  networking.hostId = "e146bb8a";

  # Use networkmanager
  networking.networkmanager.enable = true;

  # Add the rtl88xxau aircrack drivers
  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];

  # Do not compress with zstd since I normally build this locally
  sdImage.compressImage = false;
}
