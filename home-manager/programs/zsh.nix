{currentSystemName, ...}: {
  programs.zsh = {
    enable = true;

    shellAliases = {
      cdg = "cd $HOME/src";
      cdr = "cd $(git rev-parse --show-toplevel)";
      darwin-switch = "darwin-rebuild switch --flake ~/src/nix-config#${currentSystemName}";
      nixos-switch = "sudo nixos-rebuild switch --flake /persist/etc/nix-config#${currentSystemName}";
      g = "git";
      l = "ls -tlrh --color=auto";
      la = "ls -tlrha --color=auto";
      n = "nvim";
    };

    initExtra = ''
      # Bind keyboard control characters to useful functions
      # TODO: Understand why using zsh from nix breaks home / end / del
      bindkey '^[[1~' beginning-of-line               # Home / Fn Left-Arrow
      bindkey '^[[5~' beginning-of-buffer-or-history  # Page-up / Fn Up-Arrow
      bindkey '^[[4~' end-of-line                     # End / Fn Right-Arrow
      bindkey '^[[6~' end-of-buffer-or-history        # Page-down / Fn Down-Arrow
      bindkey '^[[3~' delete-char                     # Del / Fn delete
      bindkey '^[[1;3D' backward-word                 # Option Left-Arrow
      bindkey '^[[1;3C' forward-word                  # Option Right-Arrow

      # Bind ctrl-v to editing the current command line in EDITOR
      autoload -z edit-command-line
      zle -N edit-command-line
      bindkey "^V" edit-command-line
    '';

    sessionVariables = {
      CLICOLOR = "1";
    };
  };
}
