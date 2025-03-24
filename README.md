# Nix Config

My nix config, now flake based.

## Installing git hooks

```console
./tools/bin/install-git-hooks
```

## Installing remote machine

```console
nix run github:nix-community/nixos-anywhere -- --flake .#ha --target-host nixos@IP
```
