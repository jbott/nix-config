(self: super: {
  blueutil = self.callPackage ./pkgs/blueutil {};
  deconz-aarch64 = self.qt5.callPackage ./pkgs/deconz-aarch64 {};
  deploy-nixos = self.callPackage ./pkgs/deploy-nixos {};
  m1ddc = self.callPackage ./pkgs/m1ddc {};

  python311 = super.python311.override {packageOverrides = import ./pkgs/python-modules;};
  python312 = super.python312.override {packageOverrides = import ./pkgs/python-modules;};
})
