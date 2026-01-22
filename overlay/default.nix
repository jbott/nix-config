(self: super: {
  blueutil = self.callPackage ./pkgs/blueutil {};
  deconz-aarch64 = self.qt5.callPackage ./pkgs/deconz-aarch64 {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
  gen-firefox-profile-launchers = self.callPackage ./pkgs/gen-firefox-profile-launchers {};
  git-jj-wrapper = self.callPackage ./pkgs/git-jj-wrapper {};
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
