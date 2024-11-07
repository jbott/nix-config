{pkgs, ...}: {
  projectRootFile = "flake.nix";

  programs = {
    alejandra.enable = true;
    just.enable = true;
    shellcheck.enable = true;
  };

  settings = {
    formatter.shellcheck.includes = [
      "home-manager/scripts/bin/*"
      "tools/bin/*"
      "tools/git-hooks/*"
    ];
  };
}
