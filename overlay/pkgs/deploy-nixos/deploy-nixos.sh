#!/usr/bin/env bash
set -eu -o pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: deploy-nixos HOST [args]"
  exit 1
fi

host=$1
shift 1

set -x
nixos-rebuild switch \
  --fast \
  --flake ".#${host}" \
  --target-host "root@${host}" \
  "${@}"
