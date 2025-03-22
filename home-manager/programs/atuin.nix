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
}
