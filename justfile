fmt:
    treefmt

nix-flake-update:
    @git diff-index --quiet --cached HEAD || (echo "Repo has files staged! Aborting..." && exit 1)
    nix flake update --commit-lock-file --commit-lockfile-summary "nix: flake update"

diff attr:
    nvd diff $(nix build --no-link --print-out-paths "nix-config/main#{{ attr }}" ".#{{ attr }}")

diff-laptop: (diff "darwinConfigurations.jmbp.config.system.build.toplevel")
