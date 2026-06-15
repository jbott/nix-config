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
      substituters = [
        "https://cache.nixos.org/"
        "https://cache.numtide.com"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
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
