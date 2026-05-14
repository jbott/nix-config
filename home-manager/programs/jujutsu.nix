{pkgs, ...}: let
  wsrmScript = pkgs.writeShellScript "jj-wsrm" ''
    set -euo pipefail
    prog=''${1:-jj-wsrm}; shift || true
    if [ $# -eq 0 ]; then
      echo "usage: $prog <workspace>..." >&2
      exit 2
    fi
    jq=${pkgs.jq}/bin/jq
    list_tpl='if(name != "default", "{\"name\":" ++ name.escape_json() ++ ",\"root\":" ++ root.escape_json() ++ "}\n", "")'
    for ws in "$@"; do
      root=$(jj workspace list -T "$list_tpl" \
        | $jq -r --arg n "$ws" 'select(.name == $n) | .root')
      if [ -z "$root" ]; then
        echo "$prog: no such workspace: $ws" >&2
        exit 1
      fi
      jj workspace forget "$ws"
      rm -rf "$root"
      echo "removed workspace $ws ($root)" >&2
    done
  '';
in {
  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        name = "John Ott";
        email = "john@johnott.us";
      };

      aliases = {
        dt = ["diff" "--git" "--from" "latest(heads(::@ & ::trunk()))" "--to" "@"];
        lt = ["log" "-r" "trunk()..@" "--summary"];
        push = ["git" "push" "-r" "::@ & bookmarks()"];
        restack = ["rebase" "--onto" "trunk()" "--source" "mutable_roots() ~ ::(working_copies() ~ @)" "--skip-emptied" "--simplify-parents"];
        rom = ["rebase" "--onto" "trunk()" "--skip-emptied" "--simplify-parents"];
        tug = ["bookmark" "advance" "--to" "latest(::@ ~ empty())"];
        wsrm = ["util" "exec" "--" "${wsrmScript}" "jj wsrm"];
      };

      ui = {
        editor = "nvim";
        pager = "less -FXR";
      };

      revset-aliases = {
        "mutable_roots()" = "roots(trunk()..) & mutable()";
      };

      revsets = {
        log = "@ | ancestors(trunk()..(visible_heads() & mine()), 50) | ancestors(trunk()..tracked_remote_bookmarks(), 50) | trunk()";
      };

      git = {
        abandon-unreachable-commits = false;
        write-change-id-header = true;
      };

      remotes.origin.auto-track-bookmarks = "exact:main | exact:master | exact:trunk | glob:john/*";
      remotes.upstream.auto-track-bookmarks = "exact:main | exact:master | exact:trunk";

      fix.tools.treefmt = {
        command = ["treefmt" "--quiet" "--no-cache" "--stdin" "$path"];
        patterns = ["glob:'**/*'"];
      };
    };
  };
}
