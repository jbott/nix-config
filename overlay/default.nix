(self: super: {
  blueutil = self.callPackage ./pkgs/blueutil {};
  claude-code-modes = self.callPackage ./pkgs/claude-code-modes {};
  deconz-aarch64 = self.qt5.callPackage ./pkgs/deconz-aarch64 {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
  ed3d-plugins = self.callPackage ./pkgs/ed3d-plugins {};
  finicky = self.callPackage ./pkgs/finicky {};
  gen-firefox-profile-launchers = self.callPackage ./pkgs/gen-firefox-profile-launchers {};
  git-jj-wrapper = self.callPackage ./pkgs/git-jj-wrapper {};
  jj-hunk-tool = self.callPackage ./pkgs/jj-hunk-tool {};
  jj-skill = self.callPackage ../skills/jj {};
  m1ddc = self.callPackage ./pkgs/m1ddc {};
  uhubctl = super.uhubctl.overrideAttrs (final: prev: {
    buildInputs =
      prev.buildInputs
      ++ (with self; [
        git
        pkg-config
        which
      ]);
  });
})
