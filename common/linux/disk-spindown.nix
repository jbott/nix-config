{pkgs, ...}: {
  powerManagement.powerUpCommands = ''
    for f in $(${pkgs.util-linux}/bin/lsblk --nodeps --noheadings --output NAME --paths | ${pkgs.gnugrep}/bin/grep sd); do
      ${pkgs.hdparm}/sbin/hdparm -S 120 "''${f}"
    done
  '';
}
