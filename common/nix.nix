{pkgs, ...}: {
  nix = {
    package = pkgs.nix;
    settings.experimental-features = ["nix-command flakes"];
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
