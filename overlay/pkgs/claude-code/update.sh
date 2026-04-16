#!/usr/bin/env bash
# Updater for the vendored claude-code package.
#
# Fetches the latest version from Anthropic's GCS release bucket, grabs the
# per-platform hex checksums from manifest.json, converts them to SRI, and
# rewrites hashes.json in this package's source directory.
#
# Usage: update-claude-code <path-to-hashes.json>
#        (or set HASHES_FILE env var)
set -euo pipefail

HASHES_FILE="${1:-${HASHES_FILE:-}}"
if [[ -z "$HASHES_FILE" ]]; then
  echo "Usage: $0 <path-to-hashes.json>" >&2
  exit 2
fi
if [[ ! -f "$HASHES_FILE" ]]; then
  echo "claude-code: hashes file not found: $HASHES_FILE" >&2
  exit 2
fi

BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# nix system -> manifest platform key
platforms=(
  "x86_64-linux:linux-x64"
  "aarch64-linux:linux-arm64"
  "x86_64-darwin:darwin-x64"
  "aarch64-darwin:darwin-arm64"
)

latest=$(curl -sSfL "$BASE_URL/latest" | tr -d '[:space:]')
current=$(jq -r .version "$HASHES_FILE")

if [[ "$latest" == "$current" ]]; then
  echo "claude-code: already at $latest" >&2
  exit 0
fi

echo "claude-code: $current -> $latest" >&2

manifest=$(curl -sSfL "$BASE_URL/$latest/manifest.json")

new_hashes="{}"
for entry in "${platforms[@]}"; do
  nix_platform="${entry%%:*}"
  manifest_platform="${entry##*:}"
  hex=$(echo "$manifest" | jq -r ".platforms.\"$manifest_platform\".checksum")
  if [[ -z "$hex" || "$hex" == "null" ]]; then
    echo "claude-code: missing checksum for $manifest_platform" >&2
    exit 1
  fi
  sri=$(nix hash convert --hash-algo sha256 --from base16 --to sri "$hex")
  new_hashes=$(echo "$new_hashes" | jq --arg k "$nix_platform" --arg v "$sri" '. + {($k): $v}')
done

jq --arg v "$latest" --argjson h "$new_hashes" \
  '{version: $v, hashes: $h}' "$HASHES_FILE" > "$HASHES_FILE.tmp"
mv "$HASHES_FILE.tmp" "$HASHES_FILE"

echo "claude-code: updated to $latest" >&2
