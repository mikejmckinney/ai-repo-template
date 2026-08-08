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
health_attempts="${OPEN_DESIGN_HEALTH_ATTEMPTS:-60}"
health_interval="${OPEN_DESIGN_HEALTH_INTERVAL_SECONDS:-0.5}"
[[ "$health_attempts" =~ ^[1-9][0-9]*$ ]] || {
  printf 'error: OPEN_DESIGN_HEALTH_ATTEMPTS must be a positive integer\n' >&2
  exit 2
}
[[ "$health_interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
  printf 'error: OPEN_DESIGN_HEALTH_INTERVAL_SECONDS must be a non-negative number\n' >&2
  exit 2
}

check_health() {
  curl --fail --silent --show-error --max-time 2 "$health_url" >/dev/null 2>&1
}

wait_for_health() {
  local attempt
  for ((attempt = 1; attempt <= health_attempts; attempt++)); do
    if check_health; then
      return 0
    fi
    if ((attempt < health_attempts)); then
      sleep "$health_interval"
    fi
  done
  return 1
}

if ! check_health; then
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

  if ! wait_for_health; then
    printf 'error: Open Design daemon did not become healthy after %s attempts; see %s\n' \
      "$health_attempts" "$daemon_log" >&2
    exit 1
  fi
fi

if [[ "$daemon_only" == true ]]; then
  printf 'Open Design daemon is healthy at %s\n' "$daemon_url"
  exit 0
fi

exec node "$source_cli" mcp --daemon-url "$daemon_url"
