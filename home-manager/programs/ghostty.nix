{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      theme = "Argonaut";
      cursor-color = "#ffffff";
    };
  };
}
