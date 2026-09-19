{
  config,
  lib,
  pkgs,
  ...
}: let
  # Matches the socket_path atuin writes into config.toml.
  atuinSocket = "${config.home.homeDirectory}/.local/share/atuin/daemon.sock";
in {
  programs.atuin = {
    enable = true;

    # Use normal scrollback on up arrow
    flags = [
      "--disable-up-arrow"
    ];

    # Disable the update check since we're managing the version with nix
    settings = {
      update_check = false;

      # Home-manager's systemd socket uses %t, but mosh and long-lived tmux
      # shells can lack XDG_RUNTIME_DIR. Pin the client path so it still
      # reaches the listener in those shells.
      daemon.socket_path = atuinSocket;
    };

    # Enable the atuin daemon to speed up database access on zfs
    daemon.enable = true;
  };

  # Keep the socket-activated listener on the path the client was just pinned
  # to; home-manager's default is "%t/atuin.sock".
  systemd.user.sockets.atuin-daemon.Socket.ListenStream =
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux (lib.mkForce atuinSocket);

  # Home-manager pins the atuin daemon to the "user" launchd domain
  # (Background session), which doesn't reliably auto-load on GUI login
  # after a reboot. Force it back to the gui/Aqua domain. See hm#9568.
  launchd.agents.atuin-daemon.domain = "gui";

  # atuin's daemon does not unlink a stale socket before binding, so an
  # unclean shutdown (reboot) leaves daemon.sock behind and every start
  # fails with "Address already in use" (EADDRINUSE), crash-looping under
  # KeepAlive forever. Remove any stale socket before launching. This
  # mirrors home-manager's generated command (wait4path + exec) with an
  # `rm -f` spliced in.
  launchd.agents.atuin-daemon.config.ProgramArguments = lib.mkForce [
    "/bin/sh"
    "-c"
    "/bin/wait4path /nix/store && /bin/rm -f '${atuinSocket}' && exec ${config.programs.atuin.package}/bin/atuin daemon start"
  ];
}
