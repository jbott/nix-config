# Keyboards

ZMK configs, built by `overlay/pkgs/toucan-firmware` via
[zmk-nix](https://github.com/lilyinstarlight/zmk-nix).

```sh
nix build .#toucan-firmware              # all three images into ./result
nix build .#toucan-firmware.left         # or a single one: .left/.right/.settingsReset
nix build .#toucan-firmware.src          # the composed config tree, for debugging
```

The first build spends ~25 minutes fetching the west workspace (a fixed-output
derivation, so it is cached afterwards and shared by all three images).

Flash by double-tapping reset on a half and copying the matching `.uf2` onto the
mass storage device that appears.

## toucan

Upstream [beekeeb/zmk-keyboard-toucan](https://github.com/beekeeb/zmk-keyboard-toucan)
is pinned by rev in the package and supplies the shields, `zephyr/module.yml` and
`config/west.yml`. Only files we diverge on live here in `toucan/`; they are copied
over upstream's `config/` at build time, so adding e.g. a `toucan_left.conf`
alongside the keymap is enough to override that file too.

Bump `upstream` in the package to follow upstream — if `config/west.yml` changed,
`zephyrDepsHash` needs bumping as well (build, then copy the "got:" hash).
