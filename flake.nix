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
    home-manager,
    impermanence,
    llm-agents,
    nix-darwin,
    nix-rosetta-builder,
    nixpkgs,
    treefmt-nix,
  } @ inputs: let
    inherit (nix-darwin.lib) darwinSystem;
    inherit (nixpkgs.lib) nixosSystem;

    currentSystemNameModule = name: {_module.args.currentSystemName = name;};

    llmAgentsOverlay = final: _prev: {
      agent-browser = llm-agents.packages.${final.stdenv.hostPlatform.system}.agent-browser;
      ccusage = llm-agents.packages.${final.stdenv.hostPlatform.system}.ccusage;
      claude-code = llm-agents.packages.${final.stdenv.hostPlatform.system}.claude-code;
      codex = llm-agents.packages.${final.stdenv.hostPlatform.system}.codex;
    };

    fastNixGcOverlay = final: _prev: {
      # Two integration tests assume Linux filesystem semantics and fail on APFS
      # (non-UTF8 store names rejected with EILSEQ; tmp FIFO handling differs), so
      # skip the checkPhase on Darwin. Tests still run on our Linux hosts.
      fast-nix-gc = fast-nix-gc.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
        doCheck = !final.stdenv.hostPlatform.isDarwin;
      });
    };

    overlays = [
      llmAgentsOverlay
      fastNixGcOverlay
      (import ./overlay)
    ];
    nixpkgsOverlaysModule = {
      nixpkgs = {
        inherit overlays;
        config.allowUnfree = true;
      };
    };

    # The systems llm-agents and fast-nix-gc publish packages for.
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    pkgsFor = nixpkgs.lib.genAttrs systems (system:
      import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      });
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems
      (system:
        f {
          inherit system;
          pkgs = pkgsFor.${system};
        });

    treefmtEval = pkgs: treefmt-nix.lib.evalModule pkgs ./tools/treefmt.nix;
  in {
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
    };

    formatter = forAllSystems ({pkgs, ...}: (treefmtEval pkgs).config.build.wrapper);

    packages = forAllSystems ({pkgs, ...}: {
      inherit (pkgs) claude-code claude-code-modes dd-cli deploy-nixos fast-nix-gc finicky glab-jj jabracli jj-hunk-tool jj-skill jjw jujutsu;
    });

    devShells = forAllSystems ({
      system,
      pkgs,
    }: {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          deploy-nixos
          nvd
          self.formatter.${system}
        ];
      };
    });

    # Everything CI builds and caches for this system.
    checks = forAllSystems ({
      system,
      pkgs,
    }: let
      inherit (nixpkgs) lib;

      # Hosts whose platform matches this system, keyed by their CI check name.
      hostToplevels = prefix: configurations:
        lib.mapAttrs' (name: host: lib.nameValuePair "${prefix}-${name}" host.config.system.build.toplevel)
        (lib.filterAttrs (_: host: host.pkgs.stdenv.hostPlatform.system == system) configurations);

      # The rosetta builder VM image is aarch64-linux but lives in the darwin
      # system closure. Mac CI runners can't build it, so the aarch64-linux job
      # builds it and pushes it to the binary cache for the darwin job to fetch.
      rosettaBuilderImages = lib.concatMapAttrs (name: host: let
        cfg = host.config.nix-rosetta-builder;
      in
        lib.optionalAttrs (cfg.enable && system == "aarch64-linux") {
          "rosetta-builder-image-${name}" = nix-rosetta-builder.packages.${system}.image.override {
            debugInsecurely = false;
            inherit (cfg) onDemand onDemandLingerMinutes potentiallyInsecureExtraNixosModule;
          };
        })
      self.darwinConfigurations;
    in
      {
        formatting = (treefmtEval pkgs).config.build.check self;
        devshell = self.devShells.${system}.default;
      }
      // lib.mapAttrs' (name: lib.nameValuePair "package-${name}")
      (lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) self.packages.${system})
      // hostToplevels "nixos" self.nixosConfigurations
      // hostToplevels "darwin" self.darwinConfigurations
      // rosettaBuilderImages);
  };
}
