{
  config,
  lib,
  pkgs,
  currentSystemName,
  modulesPath,
  ...
}: {
  imports = [
    ./disko-config.nix
    ../../common/linux/zfs-impermanence.nix
    ../../services/home-assistant.nix
    ../../services/homebridge.nix
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

  virtualisation.containerd.enable = true;
  virtualisation.containerd.settings = {
    grpc.gid = config.users.groups.wheel.gid;
    plugins."io.containerd.cri.v1.images".snapshotter = "overlayfs";
    plugins."io.containerd.grpc.v1.cri".containerd.snapshotter = "overlayfs";
    plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc = {
      runtime_type = "io.containerd.runsc.v1";
    };
  };
  environment.systemPackages = [ pkgs.gvisor ];

  # ===== Hacky config for some HAP thing I don't want to fully codify yet ===== #
  # HAP advertising port
  networking.firewall.allowedTCPPorts = [51926];

  # Avahi to enable HAP discovery
  services.avahi.enable = true;
  services.avahi.publish.enable = true;

  # Enable linger so systemd user units start at boot
  users.users.jbo.linger = true;
}
