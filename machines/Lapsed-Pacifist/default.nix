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

  # ===== Hacky config for some HAP thing I don't want to fully codify yet ===== #
  # HAP advertising port
  networking.firewall.allowedTCPPorts = [ 51926 ];

  # Avahi to enable HAP discovery
  services.avahi.enable = true;
  services.avahi.publish.enable = true;

  # Enable linger so systemd user units start at boot
  users.users.jbo.linger = true;
}
