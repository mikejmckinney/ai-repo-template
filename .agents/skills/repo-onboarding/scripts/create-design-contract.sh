#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET="$SCRIPT_DIR/../assets/DESIGN.md"
REPO="$PWD"

fail() {
  printf 'create-design-contract: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -d "$REPO" ]] || fail "--repo must be an existing directory"
[[ -f "$ASSET" ]] || fail "canonical design asset is missing"
[[ ! -e "$REPO/DESIGN.md" ]] || fail "DESIGN.md already exists; preserve and edit it in place"

cp "$ASSET" "$REPO/DESIGN.md"
printf 'Created %s from the canonical design-contract asset.\n' "$REPO/DESIGN.md"
