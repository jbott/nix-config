{
  # Enable pam_tid.so
  security.pam.enableSudoTouchIdAuth = true;

  # Point nix-darwin to the existing user
  users.users.jbo = {
    name = "jbo";
    home = "/Users/jbo";
  };
}
