{lib, ...}: {
  system.stateVersion = 5;

  # Enable pam_tid.so
  security.pam.enableSudoTouchIdAuth = true;

  home-manager.users.jbo.programs.zsh.sessionVariables = {
    SSH_AUTH_SOCK = "/Users/jbo/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
  };
}
