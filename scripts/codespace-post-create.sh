#!/usr/bin/env bash
# Install the repository's pinned development tools when a container is created.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${CODESPACE_POST_CREATE_INSTALLER:-$SCRIPT_DIR/install-codespace-tools.sh}"

[[ -x "$INSTALLER" ]] || {
  printf 'codespace-post-create: installer is missing or not executable: %s\n' "$INSTALLER" >&2
  exit 1
}

bash "$INSTALLER" --profile default
