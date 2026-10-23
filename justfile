fmt:
    treefmt

# Bump pinned GitHub Actions to their newest release at least 7 days old
actions-update:
    GITHUB_TOKEN="$(gh auth token)" pinact run --update --min-age 7

nix-flake-update:
    @git diff-index --quiet --cached HEAD || (echo "Repo has files staged! Aborting..." && exit 1)
    nix flake update --commit-lock-file --commit-lockfile-summary "nix: flake update"

build-darwin machine:
    nix build ".#darwinConfigurations.{{ machine }}.config.system.build.toplevel"

build-nixos machine:
    nix build ".#nixosConfigurations.{{ machine }}.config.system.build.toplevel"

diff attr:
    nvd diff $(nix build --no-link --print-out-paths "nix-config/main#{{ attr }}" ".#{{ attr }}")

diff-laptop: (diff "darwinConfigurations.jmbp.config.system.build.toplevel")
