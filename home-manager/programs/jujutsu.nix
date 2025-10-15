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
        poh = ["git" "push" "--revisions" "@" "--allow-new"];
      };

      ui = {
        editor = "nvim";
        pager = "less -FXR";
      };

      git = {
        abandon-unreachable-commits = false;
        write-change-id-header = true;
      };

      templates = {
        git_push_bookmark = "\"jbott-\" ++ change_id.short()";
      };

      fix.tools.treefmt = {
        command = ["treefmt" "--stdin" "$path"];
        patterns = ["glob:'**/*'"];
      };
    };
  };
}
