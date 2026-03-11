{
  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        name = "John Ott";
        email = "john@johnott.us";
      };

      aliases = {
        dt = ["diff" "--from" "latest(heads(::@ & ::trunk()))" "--to" "@"];
        lt = ["log" "-r" "trunk()..@"];
        push = ["git" "push" "-r" "::@ & bookmarks()"];
        restack = ["rebase" "--onto" "trunk()" "--source" "mutable_roots() ~ ::(working_copies() ~ @)" "--skip-emptied" "--simplify-parents"];
        rom = ["rebase" "--onto" "trunk()" "--skip-emptied" "--simplify-parents"];
        tug = ["bookmark" "advance" "--to" "latest(::@ ~ empty())"];
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
