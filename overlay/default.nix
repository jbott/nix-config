(self: super: {
  claude-code-modes = self.callPackage ./pkgs/claude-code-modes {};
  dd-cli = self.callPackage ./pkgs/dd-cli {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
  ed3d-plugins = self.callPackage ./pkgs/ed3d-plugins {};
  finicky = self.callPackage ./pkgs/finicky {};
  gen-firefox-profile-launchers = self.callPackage ./pkgs/gen-firefox-profile-launchers {};
  glab-jj = self.callPackage ./pkgs/glab-jj {};
  humanizer-skill = self.callPackage ./pkgs/humanizer-skill {};
  jj-hunk-tool = self.callPackage ./pkgs/jj-hunk-tool {};
  jj-skill = self.callPackage ../skills/jj {};
  jjw = self.callPackage ./pkgs/jjw {};
  jujutsu = self.callPackage ./pkgs/jujutsu {jujutsu = super.jujutsu;};
  paseo = self.callPackage ./pkgs/paseo {};
  yolo = self.callPackage ./pkgs/yolo {};
})
