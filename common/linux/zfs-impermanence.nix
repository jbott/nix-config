# Config to rollback zfs filesystems on boot
# Inspired by https://grahamc.com/blog/erase-your-darlings
{lib, ...}: {
  boot.initrd.postResumeCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

  # Set noop scheduler for zfs partitions
  # source: https://github.com/cole-h/nixos-config/blob/3589d53515921772867065150c6b5a500a5b9a6b/hosts/scadrial/modules/services.nix#L70
  services.udev.extraRules = ''
    KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"
  '';

  # Use a bind mount to map data onto /persist
  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd/timesync"
    ];
  };
}
