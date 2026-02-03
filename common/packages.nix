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
    black
    btop
    cdrtools
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
    llm-agents.claude-code
    llm-agents.gemini-cli
    minicom
    mosh
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
}
