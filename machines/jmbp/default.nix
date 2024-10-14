{lib, ...}: {
  system.stateVersion = 5;

  # Enable pam_tid.so
  security.pam.enableSudoTouchIdAuth = true;
}
