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
    nix-search-cli = {
      url = "github:peterldowns/nix-search-cli";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    flake-utils,
    home-manager,
    nix-darwin,
    nix-search-cli,
    nixpkgs,
  } @ inputs: let
    inherit (flake-utils.lib) eachDefaultSystem;
    inherit (nix-darwin.lib) darwinSystem;
    inherit (nixpkgs.lib) nixosSystem;

    allowUnfreeModule = {nixpkgs.config.allowUnfree = true;};
    currentSystemNameModule = name: {_module.args.currentSystemName = name;};
    nixpkgsOverlaysModule = {
      nixpkgs.overlays = [
        (import ./overlay)
        (self: super: {
          nix-search-cli = nix-search-cli.packages.${self.system}.default;
        })
      ];
    };

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
            nixpkgsOverlaysModule
            home-manager.darwinModules.default
            ./common
            ./common/darwin
            ./home-manager
            ./machines/Just-Another-Victim-of-the-Ambient-Morality
          ];
          specialArgs = {inherit inputs;};
        };
      };
      nixosConfigurations = {
        Only-Slightly-Bent = nixosSystem {
          system = "x86_64-linux";
          modules = [
            (currentSystemNameModule "Only-Slightly-Bent")
            nixpkgsOverlaysModule
            home-manager.nixosModules.default
            ./common
            ./common/linux
            ./home-manager
            ./machines/Only-Slightly-Bent
          ];
          specialArgs = {inherit inputs;};
        };
        Lapsed-Pacifist = nixosSystem {
          system = "aarch64-linux";
          modules = [
            (currentSystemNameModule "Lapsed-Pacifist")
            allowUnfreeModule
            nixpkgsOverlaysModule
            home-manager.nixosModules.default
            ./common
            ./common/linux
            ./home-manager
            ./machines/Lapsed-Pacifist
          ];
          specialArgs = {inherit inputs;};
        };
      };
    }
    // allSystemsOutput;
}
