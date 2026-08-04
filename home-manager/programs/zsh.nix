{currentSystemName, ...}: {
  programs.zsh = {
    enable = true;
    syntaxHighlighting = {
      enable = true;
      styles = {
        single-hyphen-option = "fg=yellow";
        double-hyphen-option = "fg=yellow";
      };
    };

    shellAliases = {
      cdg = "cd $HOME/src";
      cdp = "cd $(get-project-dir)";
      cdr = "cd $(git rev-parse --show-toplevel)";
      cdz = "cd $HOME/src/zelos/src";
      darwin-switch = "sudo darwin-rebuild switch --flake ~/src/nix-config#${currentSystemName}";
      g = "git";
      j = "just";
      jw = "watchexec just";
      jwr = "watchexec --restart just";
      l = "ls -tlrh --color=auto";
      la = "ls -tlrha --color=auto";
      n = "nvim";
      nixos-switch = "sudo nixos-rebuild switch --flake /persist/etc/nix-config#${currentSystemName}";
      pip-compile = "uv pip compile";
      tf = "terraform";
    };

    initContent = ''
      # These wrap the `jjw` binary (overlay/pkgs/jjw, also `jj w`) to add the one
      # thing a binary cannot do: cd the calling shell.

      # A bare `jjw <name>` is shorthand for branching off main with a
      # john/<name> bookmark; other arguments go straight to the binary.
      jjw() {
        case ''${1-} in
          new)
            local out
            out=$(command jjw "$@") || return
            cd "$out"
            ;;
          "" | -* | rm | ls | root)
            command jjw "$@"
            ;;
          *)
            local out
            out=$(command jjw new -r main -b "john/$1" "$1") || return
            cd "$out"
            ;;
        esac
      }

      # Shadows the `w` who-is-logged-in utility, which we never use.
      w() {
        if (($# == 0)); then
          command jjw ls
          return
        fi
        (($# == 1)) || {
          echo "usage: w [<workspace>|^]" >&2
          return 1
        }
        local dir
        # `^` is the main workspace. It resolves without a recorded path, which
        # repos initialized before jj 0.38 lack for their original workspace.
        if [[ $1 == "^" ]]; then
          dir=$(command jjw root) || return
        else
          dir=$(command jjw root "$1") || return
        fi
        cd "$dir"
      }

      # Disable 'r' for running the last command
      disable r

      # Configure zle in emacs mode
      bindkey -e

      # Force block cursor (ZLE can switch it to a bar)
      zle-line-init() { printf '\e[2 q'; }
      zle -N zle-line-init

      # Bind keyboard control characters to useful functions
      # TODO: Understand why using zsh from nix breaks home / end / del
      bindkey '^[[1~' beginning-of-line               # Home / Fn Left-Arrow
      bindkey '^[[5~' beginning-of-buffer-or-history  # Page-up / Fn Up-Arrow
      bindkey '^[[4~' end-of-line                     # End / Fn Right-Arrow
      bindkey '^[[6~' end-of-buffer-or-history        # Page-down / Fn Down-Arrow
      bindkey '^[[3~' delete-char                     # Del / Fn delete
      # Make word navigation stop at all boundaries (bash-style)
      autoload -U select-word-style
      select-word-style bash

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
