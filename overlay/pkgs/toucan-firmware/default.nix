{
  lib,
  buildKeyboard,
  fetchFromGitHub,
  runCommand,
  # Our config, overlaid onto upstream's config/ directory. Not named `src`
  # because callPackage would then inject the `pkgs.src` alias over the default.
  localConfig ? ../../../keyboards/toucan,
}: let
  version = "0-unstable-2026-06-28";

  # Provides the toucan and nice_view_gem shields, zephyr/module.yml and the
  # west manifest. Bump rev + hash to follow upstream.
  upstream = fetchFromGitHub {
    owner = "beekeeb";
    repo = "zmk-keyboard-toucan";
    rev = "7154e0187128e493cd15785a18af1546419d5bb1";
    hash = "sha256-CHqa/+Ts79uby6f/ceVipKG/+GrdfxWXIKcNwe9abGM=";
  };

  # Anything in keyboards/toucan wins over the same-named file in upstream's
  # config/, so we only carry the files we actually diverge on.
  src = runCommand "toucan-config-${version}" {} ''
    cp -r --no-preserve=mode ${upstream} $out
    cp -r --no-preserve=mode ${localConfig}/. $out/config/
  '';

  # Hash of the west workspace pinned by config/west.yml (ZMK v0.3 plus the
  # cirque and rgbled-widget modules). Bump whenever west.yml changes: build,
  # then copy the "got:" hash from the error.
  zephyrDepsHash = "sha256-vWkof2b17gLgKemffXlEbNKU2qerX2b+ylp0l5lh/xk=";

  common = {
    inherit src version zephyrDepsHash;
    board = "seeeduino_xiao_ble";
  };

  # Matches upstream's build.yaml matrix. The left half is the central side, so
  # it is the one that gets ZMK Studio.
  left = buildKeyboard (common
    // {
      name = "toucan-firmware-left";
      shield = "toucan_left rgbled_adapter nice_view_gem";
      enableZmkStudio = true;

      # ZMK Studio pulls in nanopb, whose protoc wrapper still imports
      # pkg_resources; setuptools 81 removed it. Runs after zmk-nix's own
      # postConfigure, so the generator has already been made executable.
      postConfigure = ''
        substituteInPlace \
          ../modules/lib/nanopb/generator/proto/__init__.py \
          ../modules/lib/nanopb/generator/proto/_utils.py \
          --replace-fail 'import pkg_resources' 'import importlib.resources' \
          --replace-fail "pkg_resources.resource_filename('grpc_tools', '_proto')" \
                         "str(importlib.resources.files('grpc_tools') / '_proto')"
      '';
    });

  # Reuse the left half's west workspace so the deps are fetched once.
  inherit (left) westDeps;

  right = buildKeyboard (common
    // {
      name = "toucan-firmware-right";
      shield = "toucan_right rgbled_adapter";
      inherit westDeps;
    });

  settingsReset = buildKeyboard (common
    // {
      name = "toucan-firmware-settings-reset";
      shield = "settings_reset";
      inherit westDeps;
    });
in
  runCommand "toucan-firmware-${version}" {
    inherit version;
    passthru = {inherit left right settingsReset src westDeps;};

    meta = {
      description = "ZMK firmware for the beekeeb Toucan split keyboard";
      homepage = "https://github.com/beekeeb/zmk-keyboard-toucan";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  } ''
    mkdir -p $out
    cp ${left}/zmk.uf2 $out/toucan_left.uf2
    cp ${right}/zmk.uf2 $out/toucan_right.uf2
    cp ${settingsReset}/zmk.uf2 $out/toucan_settings_reset.uf2
  ''
