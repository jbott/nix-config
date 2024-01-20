{pkgs, ...}: {
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    recursive
    (nerdfonts.override {fonts = ["SourceCodePro"];})
  ];
}
