{ pkgs, lib, config, ... }:

let
  cfg = config.services.hdmi-cec;
in {
  options.services.hdmi-cec = {
    enable = lib.mkEnableOption "HDMI-CEC remote control support via cec-ctl";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.v4l-utils ];

    services.udev.extraRules = ''
      SUBSYSTEM=="cec", GROUP="video", MODE="0660", TAG+="systemd"
    '';

    # Register as a CEC playback device, announce as active source,
    # then run cec-follower to respond to TV queries (e.g.
    # GIVE_DEVICE_POWER_STATUS). Without a persistent follower the
    # Panasonic TV gives up and won't forward remote keypresses.
    systemd.services.hdmi-cec-setup = {
      description = "HDMI-CEC playback device registration";
      wantedBy = [ "multi-user.target" ];
      wants = [ "dev-cec0.device" ];
      after = [ "dev-cec0.device" ];
      before = [ "hdmi-cec-follower.service" ];
      serviceConfig = {
        ExecStart = let cec-ctl = "${pkgs.v4l-utils}/bin/cec-ctl"; in
          "${pkgs.writeShellScript "hdmi-cec-setup" ''
            ${cec-ctl} --playback --cec-version-1.4 -o 'VacuumTube'
          ''}";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.hdmi-cec-follower = {
      description = "HDMI-CEC follower daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "hdmi-cec-setup.service" ];
      requires = [ "hdmi-cec-setup.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.v4l-utils}/bin/cec-follower";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
