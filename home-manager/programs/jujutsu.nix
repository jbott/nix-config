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
      };

      ui = {
        editor = "nvim";
        pager = "less -FXR";
      };

      git = {
        push-bookmark-prefix = "jbott-";
        abandon-unreachable-commits = false;
        write-change-id-header = true;
      };

      fix.tools.treefmt = {
        command = ["treefmt" "--stdin" "$path"];
        patterns = ["glob:'**/*'"];
      };
    };
  };
}
