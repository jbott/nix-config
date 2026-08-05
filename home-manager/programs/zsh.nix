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

      # A bare `jjw <name>` is shorthand for branching off main; other arguments
      # go straight to the binary. No bookmark is created — make one with
      # `jj bookmark create john/<name>` when there is something worth pushing.
      jjw() {
        case ''${1-} in
          new | add)
            local out
            out=$(command jjw "$@") || return
            cd "$out"
            ;;
          "" | -* | rm | ls | root)
            command jjw "$@"
            ;;
          *)
            # The shorthand takes exactly one name. Without this it would treat
            # `jjw add foo` as "create a workspace called add" and drop `foo`.
            (($# == 1)) || {
              echo "jjw: unknown command: $1 (a bare name takes no further arguments)" >&2
              return 2
            }
            local out
            out=$(command jjw new -r main "$1") || return
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

      # Existing workspaces, described by their path. `jjw ls` prints
      # <name><TAB><path>, with "-" where jj has no recorded path (repos
      # initialized before jj 0.38).
      _jjw_workspaces() {
        local -a names
        # Not `path`: that name is tied to $PATH in zsh, and assigning it here
        # would clobber the shell's command lookup.
        local name dir
        while IFS=$'\t' read -r name dir; do
          if [[ $dir == - ]]; then
            names+=("$name")
          else
            names+=("$name:$dir")
          fi
        done < <(command jjw ls 2>/dev/null)
        _describe -t workspaces workspace names
      }

      # Bookmarks are the revisions worth branching a new workspace from.
      _jjw_revisions() {
        local -a revs
        revs=(''${(fu)"$(command jj --ignore-working-copy bookmark list -T 'name ++ "\n"' 2>/dev/null)"})
        _describe -t revisions revision revs
      }

      _jjw() {
        # Step over the global -R/--repository, completing its directory.
        while (( CURRENT > 3 )) && [[ $words[2] == (-R|--repository) ]]; do
          shift 2 words
          (( CURRENT -= 2 ))
        done
        if [[ $words[CURRENT-1] == (-R|--repository) ]]; then
          _files -/
          return
        fi

        if (( CURRENT == 2 )); then
          local -a subcmds=(
            'new:create or reuse a workspace and cd to it'
            'rm:forget a workspace and delete its directory'
            'ls:list workspaces'
            'root:print a workspace root'
          )
          _describe -t commands command subcmds
          # A bare name is shorthand for `new`, which also reuses an existing
          # workspace, so those are worth offering here too.
          _jjw_workspaces
          return
        fi

        local cmd=$words[2]
        shift words
        (( CURRENT-- ))
        case $cmd in
          new | add)
            _arguments -S \
              '(-r --revision)'{-r,--revision}'[revision to branch from]:revision:_jjw_revisions' \
              '1:workspace:_jjw_workspaces'
            ;;
          rm) _jjw_workspaces ;;
          root) (( CURRENT == 2 )) && _jjw_workspaces ;;
        esac
      }

      _w() {
        (( CURRENT == 2 )) || return
        local -a main=('^:main workspace')
        _describe -t workspaces workspace main
        _jjw_workspaces
      }

      compdef _jjw jjw
      compdef _w w

      # `jj w` is a `util exec` alias, so jj's own completer sees only `util
      # exec` and offers file paths for it. Running jj's shipped _jj defines its
      # clap completer and binds `jj` to it; we then take the binding back for a
      # wrapper that handles the alias and delegates everything else. If jj ever
      # renames that completer, leave jj's own binding alone rather than break
      # `jj` completion wholesale.
      if autoload -Uz _jj && _jj >/dev/null 2>&1 && (( $+functions[_clap_dynamic_completer_jj] )); then
        _jj_w_aware() {
          if (( CURRENT > 2 )) && [[ $words[2] == w ]]; then
            shift words
            (( CURRENT-- ))
            _jjw
            return
          fi
          _clap_dynamic_completer_jj "$@"
        }
        compdef _jj_w_aware jj
      fi

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
