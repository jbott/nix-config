{
  programs.git = {
    enable = true;
    lfs.enable = true;

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
