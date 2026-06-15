{
  description = "NixOS flake-based config by github.com/jbott";

  inputs = {
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fast-nix-gc = {
      url = "github:Mic92/fast-nix-gc";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    llm-agents.url = "github:numtide/llm-agents.nix";
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
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
    fast-nix-gc,
    flake-utils,
    home-manager,
    impermanence,
    llm-agents,
    nix-darwin,
    nix-rosetta-builder,
    nixpkgs,
    treefmt-nix,
  } @ inputs: let
    inherit (flake-utils.lib) eachDefaultSystem;
    inherit (nix-darwin.lib) darwinSystem;
    inherit (nixpkgs.lib) nixosSystem;

    currentSystemNameModule = name: {_module.args.currentSystemName = name;};

    llmAgentsOverlay = final: _prev: {
      agent-browser = llm-agents.packages.${final.stdenv.hostPlatform.system}.agent-browser;
      claude-code = llm-agents.packages.${final.stdenv.hostPlatform.system}.claude-code;
    };

    fastNixGcOverlay = final: _prev: {
      # Two integration tests assume Linux filesystem semantics and fail on APFS
      # (non-UTF8 store names rejected with EILSEQ; tmp FIFO handling differs), so
      # skip the checkPhase on Darwin. Tests still run on our Linux hosts.
      fast-nix-gc =
        fast-nix-gc.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
          doCheck = !final.stdenv.hostPlatform.isDarwin;
        });
    };

    overlays = [
      (import ./overlay)
      llmAgentsOverlay
      fastNixGcOverlay
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
      packages = {
        inherit (pkgs) claude-code claude-code-modes deploy-nixos fast-nix-gc finicky jj-hunk-tool jj-skill;
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
            nix-rosetta-builder.darwinModules.default
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
      };
    }
    // allSystemsOutput;
}
