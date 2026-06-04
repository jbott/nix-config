{pkgs, ...}: let
  wsrmScript = pkgs.writeShellScript "jj-wsrm" ''
    set -euo pipefail
    prog=''${1:-jj-wsrm}; shift || true
    if [ $# -eq 0 ]; then
      echo "usage: $prog <workspace>..." >&2
      exit 2
    fi
    for ws in "$@"; do
      # Tab-separated name<TAB>root, one line per workspace. Tabs can't appear
      # in either field, so a plain read parses it without jq/JSON escaping.
      root=""
      while IFS=$'\t' read -r name r; do
        if [ "$name" = "$ws" ]; then root=$r; fi
      done < <(jj workspace list -T 'name ++ "\t" ++ root ++ "\n"')
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
        # Megamerge workflow (see https://isaaccorbrey.com/notes/jujutsu-megamerges-for-fun-and-profit):
        # - `jj stack <rev>` inserts <rev> as a new sibling parent of the
        #   closest ancestor merge — i.e. attaches a branch to the megamerge.
        # - `jj stage` folds all non-empty commits made on top of the megamerge
        #   back into the merge as additional branches in one step.
        stack = ["rebase" "--after" "trunk()" "--before" "closest_merge(@)" "--revisions"];
        stage = ["stack" "closest_merge(@)+:: ~ empty()"];
      };

      ui = {
        editor = "nvim";
        pager = "less -FXR";
      };

      revset-aliases = {
        "mutable_roots()" = "roots(trunk()..) & mutable()";
        # Topmost merge commit that is an ancestor of `to`. Backs the
        # megamerge `stack` / `stage` aliases (see jujutsu.nix aliases).
        "closest_merge(to)" = "heads(::to & merges())";
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
