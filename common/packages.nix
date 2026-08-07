{
  pkgs,
  lib,
  ...
}: let
  docker-compose = pkgs.writeShellScriptBin "docker-compose" "exec ${pkgs.docker-client}/bin/docker compose \"\$@\"";
  docker-credential-glab = pkgs.writeShellScriptBin "docker-credential-glab" "exec ${pkgs.glab}/bin/glab auth docker-helper \"\$@\"";
in {
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    agent-browser
    bitwarden-cli
    black
    btop
    cdrtools
    claude-code
    claude-code-modes
    difftastic
    docker-buildx
    docker-compose
    docker-credential-glab
    dotslash
    fast-nix-gc
    fastmod
    fd
    fzf
    gh
    git
    git-absorb
    glab
    gmailctl
    htop
    jj-hunk-tool
    jjui
    jjw
    jq
    jujutsu
    just
    kubectl
    minicom
    mosh
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
