(self: super: {
  claude-code-modes = self.callPackage ./pkgs/claude-code-modes {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
  ed3d-plugins = self.callPackage ./pkgs/ed3d-plugins {};
  finicky = self.callPackage ./pkgs/finicky {};
  gen-firefox-profile-launchers = self.callPackage ./pkgs/gen-firefox-profile-launchers {};
  git-jj-wrapper = self.callPackage ./pkgs/git-jj-wrapper {};
  humanizer-skill = self.callPackage ./pkgs/humanizer-skill {};
  jj-hunk-tool = self.callPackage ./pkgs/jj-hunk-tool {};
  jj-skill = self.callPackage ../skills/jj {};
  paseo = self.callPackage ./pkgs/paseo {};
  yolo = self.callPackage ./pkgs/yolo {};
})
