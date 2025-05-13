{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    alacritty
    atuin
    black
    btop
    cdrtools
    docker-buildx
    fastmod
    fd
    fzf
    gh
    git
    git-absorb
    gmailctl
    graphite-cli
    htop
    jq
    jujutsu
    just
    minicom
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
    rust-analyzer
    rustfmt
    starship
    tmux
    tree
    uhubctl
    uv
    vimv
    vscode-langservers-extracted
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
