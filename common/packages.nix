{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    _1password
    alacritty
    atuin
    black
    cdrtools
    docker-buildx
    fd
    git
    gmailctl
    htop
    jq
    minicom
    mtr
    neovim
    nmap
    nodePackages.prettier
    podman
    podman-compose
    python311
    python311Packages.pip-tools
    qemu
    ripgrep
    starship
    tmux
    tree
    watch
    wget
    yubikey-manager
    zsh
  ];

  nixpkgs.config.permittedInsecurePackages = [
    # Needed until https://github.com/NixOS/nixpkgs/issues/216207
    "libressl-3.4.3"
  ];

  # Allow certain unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password-cli"
    ];
}
