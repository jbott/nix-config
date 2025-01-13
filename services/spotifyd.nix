{
  pkgs,
  lib,
  ...
}: {
  services.spotifyd = {
    enable = true;
    config = ''
      [global]
      zeroconf_port = 5354

      device_type = "speaker"
      device_name = "Living Room Speaker"

      # Set audio bitrate to the max
      bitrate = 320

      # This is background, not graphical, so disable attempting to use D-Bus
      use_mpris = false

      # We use alsa
      backend = "alsa"
      volume_controller = "alsa"
    '';
  };

  # Create a non-dynamic user for this service
  systemd.services.spotifyd.serviceConfig.DynamicUser = lib.mkForce false;
  users = {
    users.spotifyd = {
      isSystemUser = true;
      home = "/home/spotifyd";
      createHome = true;
      description = "spotifyd";
      group = "spotifyd";
      shell = pkgs.bash;
      extraGroups = ["audio" "pipewire"];
    };
    groups.spotifyd = {};
  };

  # Allow ports through the firewall
  # Spotify
  networking.firewall.allowedTCPPorts = [5354];
  # mDNS
  networking.firewall.allowedUDPPorts = [5353];

  # Enable the pipewire audio daemon
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    systemWide = true;
    socketActivation = false;

    # enable alsa and pulse
    alsa.enable = true;
    pulse.enable = true;
  };
}
