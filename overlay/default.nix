(self: super: {
  deconz-aarch64 = self.qt5.callPackage ./pkgs/deconz-aarch64 {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
})
