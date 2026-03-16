{pkgs, ...}:
let
  starship-jj-dir = pkgs.writeShellScript "starship-jj-dir" ''
    if root=$(realpath "$(${pkgs.jujutsu}/bin/jj workspace root 2>/dev/null)"); then
      cwd=$(realpath "$PWD")
      repo=$(basename "$root")
      rel=''${cwd#"$root"}
      printf '%s' "$repo$rel"
    else
      printf '%s' "''${PWD/#$HOME/~}"
    fi
  '';
in
{
  home.packages = [pkgs.jj-starship];

  programs.starship = {
    enable = true;
    settings = {
      # Disable git modules — jj-starship handles both jj and colocated git
      git_branch.disabled = true;
      git_status.disabled = true;
      git_commit.disabled = true;

      # Disable nix shell indicator — always shows "impure" which isn't useful
      nix_shell.disabled = true;

      # Replace directory module with jj-aware version
      # Placing ${custom.dir} explicitly excludes it from $all, avoiding duplication
      format = "\${custom.dir}$all";
      directory.disabled = true;

      custom.dir = {
        when = "true";
        shell = ["${starship-jj-dir}"];
        style = "bold cyan";
        format = "[$output]($style) ";
      };

      # Jujutsu VCS status via jj-starship
      custom.jj = {
        when = "jj-starship detect";
        shell = ["jj-starship"];
        format = "$output ";
      };
    };
  };
}
