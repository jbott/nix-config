{
  lib,
  currentSystemName,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../../services/deconz.nix
  ];

  system.stateVersion = "23.11";

  networking.hostName = currentSystemName;
  networking.hostId = "befff1e1";

  # Do not compress with zstd since I normally build this locally
  sdImage.compressImage = false;
}
