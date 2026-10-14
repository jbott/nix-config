{pkgs, ...}: {
  # Spin spinning disks down after 10 minutes idle (-S 120 = 120 * 5s). udev
  # applies this whenever a disk appears, so hot-plugged disks get it too.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]*", ENV{DEVTYPE}=="disk", ATTR{queue/rotational}=="1", RUN+="${pkgs.hdparm}/bin/hdparm -S 120 /dev/%k"
  '';
}
