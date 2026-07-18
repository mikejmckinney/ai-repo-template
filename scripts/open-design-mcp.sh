#!/usr/bin/env bash
set -Eeuo pipefail

daemon_url="${OPEN_DESIGN_DAEMON_URL:-http://127.0.0.1:7456}"
source_root="${OPEN_DESIGN_HOME:-$HOME/.local/share/open-design}"
source_cli="$source_root/apps/daemon/bin/od.mjs"
mac_cli="/Applications/Open Design.app/Contents/Resources/app/prebundled/daemon/daemon-cli.mjs"

if [[ -f "$source_cli" ]]; then
  exec node "$source_cli" mcp --daemon-url "$daemon_url"
fi

if [[ -f "$mac_cli" ]]; then
  exec node "$mac_cli" mcp --daemon-url "$daemon_url"
fi

printf 'error: Open Design is not installed at %s or in the macOS application bundle\n' "$source_root" >&2
printf 'error: run .agents/skills/open-design/scripts/bootstrap.sh --lock .agents/skills/open-design/open-design.lock\n' >&2
exit 1
