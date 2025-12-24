#!/usr/bin/env bash
set -eu -o pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: deploy-nixos [-r|--build-remote] [--] HOST [extra args]"
  exit 1
fi

# Flags
build_remote=false

# Parse flags
while [[ $# -gt 0 ]] && [[ "$1" == "-"* ]] ;
do
    opt="$1";
    shift;              #expose next argument
    case "$opt" in
        "--" ) break 2;;
        -r|--build-remote )
           build_remote=true;;
        *) echo >&2 "Invalid option: $opt"; exit 1;;
   esac
done

# Positional args
host=$1
shift 1

# Add extra args to command from flags
extra_args=()
if [[ "$build_remote" == "true" ]]; then
  extra_args+=("--build-host" "${host}")
fi

# nixos-rebuild creates a control socket path that's too long to be a unix
# domain socket when TMPDIR is set by running in a nix shell
# See: https://github.com/NixOS/nixpkgs/issues/84803
unset TMPDIR

# Invoke wrapped command
PS4='[*] '
set -x
nixos-rebuild switch \
  --no-reexec \
  --flake ".#${host}" \
  --target-host "${host}" \
  --sudo \
  "${extra_args[@]}" \
  "${@}"
