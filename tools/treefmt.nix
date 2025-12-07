{pkgs, ...}: let
  typosConfigPath = ../.typos.toml;
  typosConfigContent = builtins.fromTOML (builtins.readFile typosConfigPath);
in {
  projectRootFile = "flake.nix";

  programs = {
    alejandra.enable = true;
    just.enable = true;
    shellcheck.enable = true;
    typos.enable = true;
  };

  settings = {
    formatter.typos = {
      configFile = typosConfigPath;
      excludes = typosConfigContent.files.extend-exclude;
    };
    formatter.shellcheck.includes = [
      "home-manager/scripts/bin/*"
      "tools/bin/*"
      "tools/git-hooks/*"
    ];
    formatter.shellcheck.excludes = [
      "home-manager/scripts/bin/humanize"
    ];
  };
}
