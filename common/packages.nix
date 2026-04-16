{
  pkgs,
  lib,
  ...
}: let
  docker-compose = pkgs.writeShellScriptBin "docker-compose" "exec ${pkgs.docker}/bin/docker compose \"\$@\"";
in {
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    atuin
    bitwarden-cli
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
    gh
    git
    git-absorb
    glab
    gmailctl
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
    nvd
    poppler-utils
    python3
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
}
