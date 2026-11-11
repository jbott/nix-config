(self: super: {
  dd-cli = self.callPackage ./pkgs/dd-cli {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
  # cargoSetupHook now forces system libraries, so zstd-sys looks for zstd with
  # pkg-config. Drop once https://github.com/NixOS/nixpkgs/pull/585851 reaches
  # nixos-unstable.
  dotslash = super.dotslash.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [self.pkg-config];
    buildInputs = (old.buildInputs or []) ++ [self.zstd];
  });
  ed3d-plugins = self.callPackage ./pkgs/ed3d-plugins {};
  finicky = self.callPackage ./pkgs/finicky {};
  glab-jj = self.callPackage ./pkgs/glab-jj {};
  humanizer-skill = self.callPackage ./pkgs/humanizer-skill {};
  jj-hunk-tool = self.callPackage ./pkgs/jj-hunk-tool {};
  jj-skill = self.callPackage ../skills/jj {};
  jjw = self.callPackage ./pkgs/jjw {};
  swiftui-pro-skill = self.callPackage ./pkgs/swiftui-pro-skill {};
  yolo = self.callPackage ./pkgs/yolo {};
})
