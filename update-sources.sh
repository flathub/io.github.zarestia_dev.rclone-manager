#!/usr/bin/env bash
# Update the shared-modules submodule and regenerate cargo-sources.json and
# npm-sources.json for the Flatpak manifest.
#
# Downloads backend/Cargo.lock and package-lock.json from the upstream repo at
# the commit pinned in the manifest, then runs flatpak-cargo-generator and
# flatpak-node-generator on them.
#
# Usage: ./update-sources.sh [commit|branch|tag]
#   With an argument, the manifest's pinned commit is updated to it first.
#   Without one, the commit already in the manifest is used.
#
# Requires: curl, git, flatpak-cargo-generator, flatpak-node-generator
#   (https://github.com/flatpak/flatpak-builder-tools)

set -euo pipefail

REPO="Zarestia-Dev/rclone-manager"
MANIFEST="io.github.zarestia_dev.rclone-manager.yml"
CARGO_LOCK_PATH="backend/Cargo.lock"
NPM_LOCK_PATH="package-lock.json"

cd "$(dirname "$(readlink -f "$0")")"

for tool in curl git flatpak-cargo-generator flatpak-node-generator; do
  command -v "$tool" >/dev/null || { echo "error: '$tool' not found in PATH" >&2; exit 1; }
done

echo "==> Updating shared-modules submodule"
git submodule update --init --remote shared-modules

if [[ $# -gt 0 ]]; then
  ref="$1"
  if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
    commit="$ref"
  else
    commit="$(git ls-remote "https://github.com/$REPO.git" "$ref" "refs/tags/$ref^{}" "refs/heads/$ref" \
      | awk 'END { print $1 }')"
    [[ -n "$commit" ]] || { echo "error: could not resolve '$ref' in $REPO" >&2; exit 1; }
  fi
  sed -i -E "s/^(\s*commit:\s*)[0-9a-f]{40}/\1$commit/" "$MANIFEST"
  echo "==> Manifest commit set to $commit"
else
  commit="$(grep -m1 -oE 'commit:\s*[0-9a-f]{40}' "$MANIFEST" | grep -oE '[0-9a-f]{40}')"
  [[ -n "$commit" ]] || { echo "error: no commit found in $MANIFEST" >&2; exit 1; }
  echo "==> Using commit $commit from manifest"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

raw="https://raw.githubusercontent.com/$REPO/$commit"
curl -fsSL "$raw/$CARGO_LOCK_PATH" -o "$tmp/Cargo.lock"
curl -fsSL "$raw/$NPM_LOCK_PATH" -o "$tmp/package-lock.json"

echo "==> Generating cargo-sources.json"
flatpak-cargo-generator "$tmp/Cargo.lock" -o cargo-sources.json

echo "==> Generating npm-sources.json"
flatpak-node-generator npm "$tmp/package-lock.json" -o npm-sources.json

echo "==> Done. Review with: git diff --stat"
