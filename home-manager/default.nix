{currentSystemName, pkgs, ...}: {
  home-manager.users.jbo = {
    # Not sure when this should change
    home.stateVersion = "22.11";

    # Pass the extra args to all home-manager modules too
    _module.args = {inherit currentSystemName;};

    imports = [
      ./programs/alacritty.nix
      ./programs/atuin.nix
      ./programs/dircolors.nix
      ./programs/direnv.nix
      ./programs/git.nix
      ./programs/neovim.nix
      ./programs/starship.nix
      ./programs/tmux
      ./programs/zoxide.nix
      ./programs/zsh.nix
    ];

    home.packages = [
      (pkgs.buildEnv {
        name = "home-manager-scripts";
        # Pull in all of the files under the scripts directory.
        # The bin/ folder is load-bearing because nix expects all binaries that
        # should be on PATH to be in the bin folder of a derivation (I think
        # those are the right words, but someone needs to make a nix
        # dictionary).
        paths = [ ./scripts ];
      })
    ];
  };
}
