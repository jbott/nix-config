{...}: {
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # This is the best we can do, the darwin config is really fake at this point
  # NOTE: this might actually be _wrong_ but I'll see later lol
  environment.darwinConfig = "$HOME/src/nix-config";
}
