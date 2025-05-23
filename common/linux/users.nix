{pkgs, ...}: {
  users = {
    mutableUsers = false;

    users.jbo = {
      isNormalUser = true;
      uid = 1000;
      name = "jbo";
      home = "/home/jbo";
      group = "jbo";
      extraGroups = [
        "dialout"
        "systemd-journal"
        "wheel"
      ];
      shell = pkgs.zsh;
      initialHashedPassword = "\$6\$QUiXYT6XzD39mklJ\$ZaA07XGXhcbaE7KB6WZBtKDpN0ZYRz/WayP038wxSDyU6E15zEOBpVCK3ChHCxvmokyeIDcc/3XkLBAZpHd5D0";
      openssh.authorizedKeys.keys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCe728NHek6pPPMX1Pn6pCV49U0Fl399m+nKnG9MPVl8CQ84Qwo0JQlnernqmi245LT307jcW+beT2eAkTmGqH4= jbo@jmbp"
      ];
    };

    groups.jbo = {
      gid = 1000;
    };
  };
}
