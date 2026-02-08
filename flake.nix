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
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/remove-options-compat";
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
    llm-agents,
    nix-darwin,
    nixos-raspberrypi,
    nixpkgs,
    treefmt-nix,
  } @ inputs: let
    inherit (flake-utils.lib) eachDefaultSystem;
    inherit (nix-darwin.lib) darwinSystem;
    inherit (nixpkgs.lib) nixosSystem;

    currentSystemNameModule = name: {_module.args.currentSystemName = name;};

    overlays = [
      (import ./overlay)
      llm-agents.overlays.default
    ];
    nixpkgsOverlaysModule = {
      nixpkgs = {
        inherit overlays;
        config.allowUnfree = true;
      };
    };

    allSystemsOutput = eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system overlays;};
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
            nixpkgsOverlaysModule
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
            nixpkgsOverlaysModule
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
            nixpkgsOverlaysModule

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
            nixpkgsOverlaysModule
            home-manager.nixosModules.default
            ./common
            ./common/linux
            ./home-manager
            ./machines/performance-artist
          ];
          specialArgs = {inherit inputs;};
        };
        vacuum-tube = nixosSystem {
          system = "aarch64-linux";
          modules = [
            # nixos-raspberrypi modules (using our nixpkgs via follows)
            nixos-raspberrypi.lib.inject-overlays
            nixos-raspberrypi.nixosModules.nixpkgs-rpi
            nixos-raspberrypi.nixosModules.raspberry-pi-4.base
            nixos-raspberrypi.nixosModules.raspberry-pi-4.display-vc4
            nixos-raspberrypi.nixosModules.sd-image

            (currentSystemNameModule "vacuum-tube")
            nixpkgsOverlaysModule
            home-manager.nixosModules.default
            ./common
            ./common/linux
            ./home-manager
            ./machines/vacuum-tube
          ];
          specialArgs = {inherit inputs;};
        };
      };
    }
    // allSystemsOutput;
}
