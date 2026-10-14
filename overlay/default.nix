(self: super: {
  # atuin 18.23.0's e2e capture test times out on aarch64-darwin, so Hydra has
  # no cached build. Drop once https://github.com/NixOS/nixpkgs/issues/573527
  # is fixed upstream.
  atuin = super.atuin.overrideAttrs (old: {
    checkFlags =
      (old.checkFlags or [])
      ++ self.lib.optional self.stdenv.hostPlatform.isDarwin "--skip=filtered_commands_leave_no_captured_output";
  });
  dd-cli = self.callPackage ./pkgs/dd-cli {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
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
