{
  description = "NixOS flake-based config by github.com/jbott";

  inputs = {
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
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
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    disko,
    flake-utils,
    home-manager,
    impermanence,
    nix-darwin,
    nix-search-cli,
    nixpkgs,
    treefmt-nix,
  } @ inputs: let
    inherit (flake-utils.lib) eachDefaultSystem;
    inherit (nix-darwin.lib) darwinSystem;
    inherit (nixpkgs.lib) nixosSystem;

    # Apply patches to nixpkgs
    patchedNixpkgs = system: let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.applyPatches {
        name = "nixpkgs-patched";
        src = nixpkgs;
        patches = [
          ./overlay/patches/450849.patch
        ];
      };

    allowUnfreeModule = {nixpkgs.config.allowUnfree = true;};
    currentSystemNameModule = name: {_module.args.currentSystemName = name;};

    overlays = [
      (import ./overlay)
      (self: super: {
        nix-search-cli = nix-search-cli.packages.${self.system}.default;
      })
    ];
    nixpkgsOverlaysModule = system: {
      nixpkgs = {
        inherit overlays;
        source = patchedNixpkgs system;
      };
    };

    allSystemsOutput = eachDefaultSystem (system: let
      pkgs = import (patchedNixpkgs system) {inherit system overlays;};
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./tools/treefmt.nix;

      treefmt = treefmtEval.config.build.wrapper;
    in {
      formatter = treefmt;
      checks = {
        formatting = treefmtEval.config.build.check self;
      };
      packages = with pkgs; {
        inherit deploy-nixos;
      };
      devShells = {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            deploy-nixos
            nvd
            treefmt
          ];
        };
      };
    });
  in
    {
      darwinConfigurations = {
        jmbp = darwinSystem {
          system = "aarch64-darwin";
          modules = [
            (currentSystemNameModule "jmbp")
            allowUnfreeModule
            (nixpkgsOverlaysModule "aarch64-darwin")
            home-manager.darwinModules.default
            ./common
            ./common/darwin
            ./home-manager
            ./machines/jmbp
          ];
          specialArgs = {inherit inputs;};
        };
      };
      nixosConfigurations = {
        Only-Slightly-Bent = nixosSystem {
          system = "x86_64-linux";
          modules = [
            (currentSystemNameModule "Only-Slightly-Bent")
            (nixpkgsOverlaysModule "x86_64-linux")
            home-manager.nixosModules.default
            ./common
            ./common/linux
            ./home-manager
            ./machines/Only-Slightly-Bent
          ];
          specialArgs = {inherit inputs;};
        };
        ha = nixosSystem {
          system = "x86_64-linux";
          modules = [
            (currentSystemNameModule "ha")
            allowUnfreeModule
            (nixpkgsOverlaysModule "x86_64-linux")

            # Flake Modules
            disko.nixosModules.disko
            home-manager.nixosModules.default
            impermanence.nixosModules.impermanence

            # First-party config
            ./common
            ./common/linux
            ./home-manager
            ./machines/ha
          ];
          specialArgs = {inherit inputs;};
        };
        performance-artist = nixosSystem {
          system = "aarch64-linux";
          modules = [
            (currentSystemNameModule "performance-artist")
            allowUnfreeModule
            (nixpkgsOverlaysModule "aarch64-linux")
            home-manager.nixosModules.default
            ./common
            ./common/linux
            ./home-manager
            ./machines/performance-artist
          ];
          specialArgs = {inherit inputs;};
        };
      };
    }
    // allSystemsOutput;
}
