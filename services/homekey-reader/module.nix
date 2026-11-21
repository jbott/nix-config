# SPDX-License-Identifier: MIT OR Apache-2.0
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homekey-reader;
  creds = "/run/credentials/homekey-reader.service";
  state = "/var/lib/homekey-reader";
  configuration = pkgs.writeText "homekey-reader.json" (builtins.toJSON {
    inherit (cfg) device express finish flow;
    state_dir = state;
    setup_pin_file = "${creds}/setup-pin";
    bind = "0.0.0.0:${toString cfg.port}";
    trigger =
      if cfg.trigger == null
      then {type = "dry_run";}
      else if builtins.isString cfg.trigger
      then "${creds}/trigger.json"
      else {
        type = "esphome";
        inherit (cfg.trigger) address entity;
        receiver_expiry = cfg.trigger.requireReceiverExpiry;
        psk_file = "${creds}/esphome-psk";
      };
  });
in {
  options.services.homekey-reader = {
    enable = lib.mkEnableOption "the Home Key NFC reader";
    device = lib.mkOption {
      type = lib.types.str;
      description = "Stable serial device path for the PN532.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 51926;
    };
    express = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    finish = lib.mkOption {
      type = lib.types.enum ["black" "silver" "tan" "gold"];
      default = "black";
    };
    flow = lib.mkOption {
      type = lib.types.enum ["fast" "standard" "attestation"];
      default = "fast";
      description = "Minimum authentication flow accepted for each tap.";
    };
    setupPinFile = lib.mkOption {
      type = lib.types.str;
      description = "Absolute runtime path to the HomeKit setup PIN.";
    };
    trigger = lib.mkOption {
      default = null;
      description = "Absolute path to a host-local action JSON file, or an inline ESPHome target. An unset target logs successful taps.";
      type = lib.types.nullOr (lib.types.either lib.types.str (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            description = "ESPHome host and API port.";
          };
          requireReceiverExpiry = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Require the gate's prepare/acknowledge/commit services to expire delayed taps at the relay.";
          };
          entity = lib.mkOption {
            type = lib.types.str;
            description = "Switch object ID.";
          };
          pskFile = lib.mkOption {
            type = lib.types.str;
            description = "Absolute runtime path to the Noise PSK.";
          };
        };
      }));
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/dev/serial/by-id/" cfg.device;
        message = "homekey-reader.device must name the PN532 under /dev/serial/by-id/.";
      }
      {
        assertion = !builtins.isString cfg.trigger || lib.hasPrefix "/" cfg.trigger;
        message = "homekey-reader.trigger must be an absolute path when loading an action file.";
      }
    ];
    users.groups.homekey-reader = {};
    users.users.homekey-reader = {
      isSystemUser = true;
      group = "homekey-reader";
      extraGroups = ["dialout"];
    };
    environment.systemPackages = [pkgs.homekey-reader];
    networking.firewall.allowedTCPPorts = [cfg.port];
    networking.firewall.allowedUDPPorts = [5353];
    environment.persistence."/persist".directories = [
      {
        directory = state;
        user = "homekey-reader";
        group = "homekey-reader";
        mode = "0700";
      }
    ];
    systemd.services.homekey-reader = {
      description = "Home Key NFC reader";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      unitConfig.AssertPathExists = "${state}/state.json";
      serviceConfig = {
        User = "homekey-reader";
        Group = "homekey-reader";
        StateDirectory = "homekey-reader";
        StateDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = "${lib.getExe pkgs.homekey-reader} serve ${configuration}";
        LoadCredential =
          ["setup-pin:${cfg.setupPinFile}"]
          ++ lib.optional (builtins.isString cfg.trigger) "trigger.json:${cfg.trigger}"
          ++ lib.optional (builtins.isAttrs cfg.trigger) "esphome-psk:${cfg.trigger.pskFile}";
        Restart = "on-failure";
        RestartSec = 3;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        DevicePolicy = "closed";
        DeviceAllow = ["char-ttyUSB rw"];
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
      };
    };
  };
}
