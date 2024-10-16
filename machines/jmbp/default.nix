{
  lib,
  pkgs,
  ...
}: {
  system.stateVersion = 5;

  # Enable pam_reattach and pam_tid
  # Inspired by the changes in https://github.com/LnL7/nix-darwin/pull/1020
  environment.etc."pam.d/sudo_local" = {
    enable = true;
    text = ''
      auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
      auth       sufficient     pam_tid.so
    '';
  };

  home-manager.users.jbo.programs.zsh.sessionVariables = {
    SSH_AUTH_SOCK = "/Users/jbo/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
  };
}
