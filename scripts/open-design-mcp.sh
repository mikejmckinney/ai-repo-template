#!/usr/bin/env bash
set -Eeuo pipefail

readonly daemon_url="${OPEN_DESIGN_DAEMON_URL:-http://127.0.0.1:7456}"
readonly source_root="${OPEN_DESIGN_HOME:-$HOME/.local/share/open-design}"
readonly source_cli="$source_root/apps/daemon/bin/od.mjs"
readonly mac_cli="/Applications/Open Design.app/Contents/Resources/app/prebundled/daemon/daemon-cli.mjs"
readonly runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/ai-repo-open-design"
readonly daemon_log="$runtime_dir/daemon.log"

daemon_only=false
if [[ "${1:-}" == "--daemon-only" ]]; then
  daemon_only=true
  shift
fi
if (($# > 0)); then
  printf 'error: unexpected argument: %s\n' "$1" >&2
  exit 2
fi

if [[ ! -f "$source_cli" ]]; then
  if [[ "$daemon_only" == true ]]; then
    printf 'error: --daemon-only requires the pinned Open Design source installation\n' >&2
    printf 'error: run bash scripts/install-media-tools.sh\n' >&2
    exit 1
  fi
  if [[ -f "$mac_cli" ]]; then
    exec node "$mac_cli" mcp --daemon-url "$daemon_url"
  fi
  printf 'error: Open Design is not installed at %s or in the macOS application bundle\n' "$source_root" >&2
  printf 'error: run bash scripts/install-media-tools.sh\n' >&2
  exit 1
fi

health_url="${daemon_url%/}/api/health"
if ! curl --fail --silent --show-error --max-time 2 "$health_url" >/dev/null 2>&1; then
  if [[ ! "$daemon_url" =~ ^http://(127\.0\.0\.1|localhost):([0-9]{1,5})/?$ ]]; then
    printf 'error: refusing to auto-start a daemon for non-loopback URL: %s\n' "$daemon_url" >&2
    exit 1
  fi
  daemon_port="${BASH_REMATCH[2]}"
  if ((daemon_port < 1 || daemon_port > 65535)); then
    printf 'error: invalid Open Design daemon port: %s\n' "$daemon_port" >&2
    exit 1
  fi

  mkdir -p "$runtime_dir"
  nohup node "$source_cli" daemon start \
    --headless --port "$daemon_port" --no-open \
    >"$daemon_log" 2>&1 </dev/null &

  for _attempt in {1..60}; do
    if curl --fail --silent --show-error --max-time 2 "$health_url" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if ! curl --fail --silent --show-error --max-time 2 "$health_url" >/dev/null 2>&1; then
    printf 'error: Open Design daemon did not become healthy; see %s\n' "$daemon_log" >&2
    exit 1
  fi
fi

if [[ "$daemon_only" == true ]]; then
  printf 'Open Design daemon is healthy at %s\n' "$daemon_url"
  exit 0
fi

exec node "$source_cli" mcp --daemon-url "$daemon_url"
