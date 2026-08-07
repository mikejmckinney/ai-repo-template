#!/usr/bin/env bash
# Install the repository's pinned development tools when a container is created.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${CODESPACE_POST_CREATE_INSTALLER:-$SCRIPT_DIR/install-codespace-tools.sh}"
PREWARM="${CODESPACE_POST_CREATE_PREWARM:-$SCRIPT_DIR/mcp-prewarm.sh}"

[[ -x "$INSTALLER" ]] || {
  printf 'codespace-post-create: installer is missing or not executable: %s\n' "$INSTALLER" >&2
  exit 1
}
[[ -x "$PREWARM" ]] || {
  printf 'codespace-post-create: MCP prewarm is missing or not executable: %s\n' "$PREWARM" >&2
  exit 1
}

bash "$INSTALLER" --profile default

prewarm_output=""
prewarm_status=0
prewarm_output="$("$PREWARM" 2>&1)" || prewarm_status=$?
if ((prewarm_status != 0)); then
  while IFS= read -r line; do
    [[ "$line" == mcp-prewarm:* ]] && printf '%s\n' "$line" >&2
  done <<<"$prewarm_output"
  printf 'codespace-post-create: MCP prewarm failed; OpenCode startup may still require a retry\n' >&2
else
  printf '%s\n' "$prewarm_output"
fi
