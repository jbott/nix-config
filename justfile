fmt:
    nix fmt

nix-flake-update:
    @git diff-index --quiet --cached HEAD || (echo "Repo has files staged! Aborting..." && exit 1)
    nix flake update --commit-lock-file --commit-lockfile-summary "nix: flake update"
