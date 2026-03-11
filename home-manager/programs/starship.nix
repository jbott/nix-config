{pkgs, ...}: {
  home.packages = [pkgs.jj-starship];

  programs.starship = {
    enable = true;
    settings = {
      # Disable git modules — jj-starship handles both jj and colocated git
      git_branch.disabled = true;
      git_status.disabled = true;
      git_commit.disabled = true;

      # Jujutsu VCS status via jj-starship
      custom.jj = {
        when = "jj-starship detect";
        shell = ["jj-starship"];
        format = "$output ";
      };
    };
  };
}
