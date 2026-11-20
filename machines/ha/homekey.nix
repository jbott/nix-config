{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homekey-reader;
  legacy = "/home/jbo/apple-home-key-reader";
  state = "/var/lib/homekey-reader";
in {
  imports = [../../services/homekey-reader/module.nix];
  # Register the ttyUSB device group even if the adapter is unplugged at boot.
  boot.kernelModules = lib.mkIf cfg.enable ["ch341"];

  services.homekey-reader = {
    enable = true;
    device = "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0";
    setupPinFile = "/persist/secrets/homekey-setup-pin";
    trigger = "/persist/etc/homekey-reader/trigger.json";
  };

  systemd.services = lib.mkIf cfg.enable {
    # A running user unit can outlive the generation that installed it.
    # Release the UART and HAP listener before taking the snapshot.
    homekey-reader-handoff = {
      description = "Release the scanner from the legacy user service";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [pkgs.systemd pkgs.coreutils];
      script = ''
        if systemctl is-active --quiet "user@$(id -u jbo).service"; then
          userctl() { systemctl --user --machine=jbo@.host "$@"; }
          active=$(userctl show apple-home-key-reader.service -p ActiveState --value)
          case "$active" in
            inactive|failed) ;;
            *) userctl stop apple-home-key-reader.service ;;
          esac
        fi
      '';
    };
    homekey-reader-import = {
      description = "Import the existing Apple Home pairings and Home Keys once";
      requires = ["homekey-reader-handoff.service"];
      after = ["homekey-reader-handoff.service"];
      unitConfig = {
        RequiresMountsFor = [state];
        ConditionPathExists = "!${state}/state.json";
      };
      serviceConfig = {
        Type = "oneshot";
        User = "homekey-reader";
        Group = "homekey-reader";
        StateDirectory = "homekey-reader";
        StateDirectoryMode = "0700";
        UMask = "0077";
        LoadCredential = ["legacy-hap:${legacy}/hap.state" "legacy-homekey:${legacy}/homekey.json"];
        ExecStart = "${lib.getExe pkgs.homekey-reader} import %d/legacy-hap %d/legacy-homekey ${state}";
        ProtectHome = true;
        ProtectSystem = "strict";
        PrivateNetwork = true;
        NoNewPrivileges = true;
      };
    };
    homekey-reader = {
      requires = ["homekey-reader-handoff.service"];
      after = ["homekey-reader-handoff.service" "systemd-modules-load.service"];
      unitConfig.RequiresMountsFor = [state];
      serviceConfig.LoadCredential = lib.optional (builtins.isString cfg.trigger) "esphome-psk:/persist/etc/homekey-reader/esphome-psk";
    };
  };
}
