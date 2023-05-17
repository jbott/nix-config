{
  pkgs,
  inputs,
  ...
}: {
  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = ["nix-command flakes"];
      trusted-users = ["jbo"];
    };
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';

    registry.nixpkgs.flake = inputs.nixpkgs;
  };
}
