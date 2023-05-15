{...}: {
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # This is the best we can do, the darwin config is really fake at this point
  # NOTE: this might actually be _wrong_ but I'll see later lol
  environment.darwinConfig = "$HOME/src/nix-config";
}
