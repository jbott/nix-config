{lib, ...}: {
  # Enable pam_tid.so
  security.pam.enableSudoTouchIdAuth = true;
}
