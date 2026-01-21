{
  pkgs,
  lib,
  ...
}: let
  docker-compose = pkgs.writeShellScriptBin "docker-compose" "exec ${pkgs.docker}/bin/docker compose \"\$@\"";
in {
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    alacritty
    atuin
    black
    btop
    cdrtools
    claude-code
    difftastic
    docker
    docker-buildx
    docker-compose
    dotslash
    fastmod
    fd
    fzf
    gemini-cli
    gh
    git
    git-absorb
    glab
    gmailctl
    graphite-cli
    htop
    jjui
    jq
    jujutsu
    just
    kubectl
    minicom
    mtr
    neovim
    nix-output-monitor
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
    # keep-sorted end
  ];

  # Allow certain unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      # keep-sorted start
      "graphite-cli"
      # keep-sorted end
    ];
}
