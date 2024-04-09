{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
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
    graphite-cli
    htop
    jq
    just
    just
    minicom
    mosh
    mtr
    neovim
    nix-output-monitor
    nix-search-cli
    nmap
    nodePackages.prettier
    nvd
    python311
    rclone
    ripgrep
    starship
    tmux
    tree
    uv
    vimv
    watch
    watchexec
    wget
    yq
    yubikey-manager
    zsh
  ];

  # Allow certain unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "graphite-cli"
    ];
}
