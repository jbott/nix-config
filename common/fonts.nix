{pkgs, ...}: {
  fonts.packages = with pkgs; [
    recursive
    (nerdfonts.override {fonts = ["SourceCodePro"];})
  ];
}
