{
  users.users.backup = {
    isSystemUser = true;
    description = "Backup user";
    group = "backup";
    createHome = false;
  };
  users.groups.backup = {};

  # Ensure permissions on backup directory
  systemd.tmpfiles.rules = [
    "d /backups 0755 backup backup -"
  ];

  # Enable Samba service
  services.samba = {
    enable = true;
    openFirewall = false; # We manage firewall manually for tailscale
    settings = {
      global = {
        "server role" = "standalone server";
        "server min protocol" = "SMB3";
        # Order of vfs objects is important: aio_pthread must be last
        "vfs objects" = "acl_xattr fruit streams_xattr aio_pthread";
        "fruit:aapl" = "yes";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
        "fruit:nfs_aces" = "no";
        "fruit:wipe_intentionally_left_behind_if_posix_unlink_fails" = "yes";
        "fruit:delete_empty_adfiles" = "yes";

        "security" = "user";
        "map to guest" = "Never";

        # Performance and locking
        "oplocks" = "yes";
        "locking" = "yes";
        "strict locking" = "no";
      };
      "Backups" = {
        path = "/backups";
        "valid users" = "backup";
        "guest ok" = "no";
        writeable = "yes";
        "force user" = "backup";
        "force group" = "backup";
        "fruit:time machine" = "yes";
        "recycle:keeptree" = "no";
      };
    };
  };

  # Use bind mounts to map Samba state onto /persist
  fileSystems."/var/lib/samba" = {
    device = "/persist/var/lib/samba";
    options = ["bind"];
  };

  # Open firewall for Samba on Tailscale interface only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [445];
  networking.firewall.interfaces.tailscale0.allowedUDPPorts = [137 138];
}
