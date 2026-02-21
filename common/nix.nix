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
      download-buffer-size = 128 * 1024 * 1024; # 128 MiB
      max-jobs = "auto";
      auto-optimise-store = true;
      http-connections = 128;
      max-substitution-jobs = 128;
      warn-dirty = false;
    };
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
    '';

    registry.nixpkgs.flake = inputs.nixpkgs;
    registry.nix-config = {
      to = {
        type = "github";
        owner = "jbott";
        repo = "nix-config";
      };
      exact = false;
    };
  };
}
