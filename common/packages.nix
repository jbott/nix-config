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
    fzf
    gh
    git
    gmailctl
    htop
    jq
    just
    minicom
    mosh
    mtr
    neovim
    nix-search-cli
    nmap
    nodePackages.prettier
    python311
    python311Packages.pip-tools
    ripgrep
    starship
    tmux
    tree
    watch
    wget
    yq
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
