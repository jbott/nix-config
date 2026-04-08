{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      background = "#121212";
      foreground = "#f7f7f8";
      cursor-color = "#7de486";
      cursor-style = "block";
      selection-background = "#7de486";
      selection-foreground = "#121212";
      palette = [
        "0=#1e2025"
        "1=#f82871"
        "2=#96df71"
        "3=#fee56c"
        "4=#10a793"
        "5=#c74cec"
        "6=#08e7c5"
        "7=#f7f7f8"
        "8=#908e96"
        "9=#ff4f8f"
        "10=#b0ff8a"
        "11=#fff08a"
        "12=#20ccb5"
        "13=#da7af7"
        "14=#30ffe0"
        "15=#ffffff"
      ];
    };
  };
}
