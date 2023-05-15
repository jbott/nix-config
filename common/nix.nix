{pkgs, ...}: {
  nix.package = pkgs.nix;
  nix.settings.experimental-features = ["nix-command flakes"];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
