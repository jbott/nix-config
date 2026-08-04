{pkgs, ...}: {
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
        # Workspace helper; owns the path convention shared with the Claude Code
        # worktree hooks.
        w = ["util" "exec" "--" "${pkgs.jjw}/bin/jjw"];
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
