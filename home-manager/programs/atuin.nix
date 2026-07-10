{
  programs.atuin = {
    enable = true;

    # Use normal scrollback on up arrow
    flags = [
      "--disable-up-arrow"
    ];

    # Disable the update check since we're managing the version with nix
    settings = {
      update_check = false;
    };

    # Enable the atuin daemon to speed up database access on zfs
    daemon.enable = true;
  };

  # Home-manager pins the atuin daemon to the "user" launchd domain
  # (Background session), which doesn't reliably auto-load on GUI login
  # after a reboot. Force it back to the gui/Aqua domain. See hm#9568.
  launchd.agents.atuin-daemon.domain = "gui";
}
