{
  description = "NixOS flake-based config by github.com/jbott";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    flake-utils,
    home-manager,
    nix-darwin,
    nixpkgs,
  }: let
    inherit (flake-utils.lib) eachDefaultSystem;
    inherit (nix-darwin.lib) darwinSystem;

    currentSystemNameModule = name: { _module.args.currentSystemName = name; };

    allSystemsOutput = eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      formatter = pkgs.alejandra;
    });
  in
    {
      darwinConfigurations = {
        Just-Another-Victim-of-the-Ambient-Morality = darwinSystem {
          system = "aarch64-darwin";
          modules = [
            (currentSystemNameModule "Just-Another-Victim-of-the-Ambient-Morality")
            home-manager.darwinModules.default
            ./common
            ./common/darwin
            ./home-manager
            ./machines/Just-Another-Victim-of-the-Ambient-Morality.nix
          ];
        };
      };
    }
    // allSystemsOutput;
}
