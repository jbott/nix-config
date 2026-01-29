{
  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        name = "John Ott";
        email = "john@johnott.us";
      };

      aliases = {
        rom = ["rebase" "-d" "main" "--skip-emptied"];
        tug = ["bookmark" "move" "--from" "heads(::@- & bookmarks())" "--to" "@-"];
        push = ["git" "push" "-r" "::@ & bookmarks()"];
      };

      ui = {
        editor = "nvim";
        pager = "less -FXR";
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
