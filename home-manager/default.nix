{currentSystemName, ...}: {
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
  };
}
