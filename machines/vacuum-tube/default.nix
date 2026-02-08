{
  config,
  lib,
  pkgs,
  currentSystemName,
  ...
}: {
  imports = [
    ../../services/hdmi-cec.nix
  ];

  system.stateVersion = "25.05";
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # U-Boot via nixos-raspberrypi (kernel/initrd on root partition, firmware DTB passthrough)
  boot.loader.raspberry-pi.bootloader = "uboot";

  # Keep only Pi 4 essential firmware to fit in 30M partition
  boot.loader.raspberry-pi.firmwarePackage = lib.mkForce (pkgs.raspberrypifw.overrideAttrs (old: {
    installPhase = ''
      mkdir -p $out/share/raspberrypi/
      mv boot "$out/share/raspberrypi/"
      cd $out/share/raspberrypi/boot
      for f in start*.elf fixup*.dat; do
        case "$f" in
          start4.elf|fixup4.dat) ;;
          *) rm -f "$f" ;;
        esac
      done
    '';
  }));

  # Declarative config.txt additions
  hardware.raspberry-pi.config.all = {
    options.hdmi_force_hotplug = { enable = true; value = 1; };
    dt-overlays.vc4-kms-v3d.params.cma-256 = { enable = true; };
  };

  networking.hostName = currentSystemName;
  networking.hostId = "a1b2c3d4";

  # Use systemd-networkd with iwd for WiFi
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wlan" = {
    matchConfig.Name = "wlan0";
    networkConfig.DHCP = "yes";
  };
  systemd.network.networks."10-ethernet" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "yes";
  };
  networking.wireless.iwd.enable = true;

  # mDNS/Bonjour so we can reach vacuum-tube.local
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };

  # Enable auto gc
  nix.gc.automatic = true;

  # Install vacuum-tube
  environment.systemPackages = with pkgs; [
    vacuum-tube
  ];

  # HDMI-CEC support
  services.hdmi-cec.enable = true;
  users.users.jbo.extraGroups = [ "video" "input" ];

  # Remap CEC remote keys to standard keyboard codes
  services.udev.extraHwdb = ''
    evdev:name:vc4-hdmi-0:*
    evdev:name:vc4-hdmi-1:*
      KEYBOARD_KEY_00=enter
      KEYBOARD_KEY_0d=esc
      KEYBOARD_KEY_48=esc
  '';

  # Disable getty on tty1 — cage owns this TTY
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;

  # Cage kiosk compositor for auto-launching vacuum-tube
  services.cage = {
    enable = true;
    user = "jbo";
    environment.NIXOS_OZONE_WL = "1";
    program = "${pkgs.vacuum-tube}/bin/VacuumTube --enable-features=AcceleratedVideoDecodeLinux,V4L2StatefulVideoDecoder,UseMultiPlaneFormatForHardwareVideo --ignore-gpu-blocklist --enable-accelerated-video-decode --enable-zero-copy";
  };
  systemd.services.cage-tty1.serviceConfig = {
    Restart = "always";
    RestartSec = 3;
  };

  # Ensure we have audio support (headphone jack disabled, HDMI only)
  hardware.raspberry-pi.config.all.base-dt-params.audio = {
    enable = true;
    value = lib.mkForce "off";
  };
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.extraConfig."50-default-volume" = {
      "wireplumber.settings"."device.routes.default-sink-volume" = 1.0;
    };
  };
}
