{
  programs.git = {
    enable = true;
    lfs.enable = true;

    # Global ignores for Claude Code sandbox phantom files
    # See: https://github.com/anthropics/claude-code/issues/17087
    ignores = [
      ".bash_profile"
      ".bashrc"
      ".claude/"
      ".gitconfig"
      ".gitmodules"
      ".idea"
      ".mcp.json"
      ".profile"
      ".ripgreprc"
      ".vscode"
      ".zprofile"
      ".zshrc"
    ];

    settings = {
      user = {
        name = "John Ott";
        email = "john@johnott.us";
      };

      alias = {
        c = "commit";
        cfp = "commit-for-project";
        cm = "commit -m";
        co = "checkout";
        cp = "cherry-pick";
        di = "diff";
        ds = "diff --staged";
        fc = "fzf-checkout";
        fo = "fzf-oneline";
        fwl = "push --force-with-lease";
        o = "log --oneline";
        poh = "push -u origin HEAD";
        pohfwl = "push -u origin HEAD --force-with-lease";
        ri = "rebase -i";
        rim = "rebase -i origin/main";
        rom = "rebase origin/main";
        rup = "remote update -p";
        rur = "!git remote update && git rebase -i origin/main";
        st = "status";
      };

      init.defaultBranch = "main";
    };

    # Non-nix tracked configuration for per-repo identities
    # TODO: Can I pull this into the repo in an encrypted state or something?
    includes = [
      {
        path = "identities.gitconfig";
      }
    ];
  };
}
