#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-repo-media-smoke.XXXXXX")"
studio_pid=""

cleanup() {
  if [[ -n "$studio_pid" ]] && kill -0 "$studio_pid" 2>/dev/null; then
    kill "$studio_pid"
    wait "$studio_pid" 2>/dev/null || true
  fi
  case "$smoke_dir" in
    "${TMPDIR:-/tmp}"/ai-repo-media-smoke.*) rm -rf "$smoke_dir" ;;
    *) printf 'Refusing to remove unexpected smoke path: %s\n' "$smoke_dir" >&2 ;;
  esac
}
trap cleanup EXIT

cd "$repo_root"

bash scripts/open-design-mcp.sh --daemon-only
(
  cd "${OPEN_DESIGN_HOME:-$HOME/.local/share/open-design}/apps/web"
  exec env \
    NEXT_TELEMETRY_DISABLED=1 \
    NODE_OPTIONS="${OPEN_DESIGN_STUDIO_NODE_OPTIONS:---max-old-space-size=4096}" \
    OD_DAEMON_PORT=7456 \
    PORT=5173 \
    pnpm dev
) >"$smoke_dir/studio.log" 2>&1 &
studio_pid=$!

studio_status=""
for _attempt in {1..60}; do
  if studio_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    http://127.0.0.1:5173)" && [[ "$studio_status" == 200 ]]; then
    break
  fi
  if ! kill -0 "$studio_pid" 2>/dev/null; then
    printf 'error: Open Design Studio exited before becoming ready\n' >&2
    while IFS= read -r line; do printf '%s\n' "$line" >&2; done <"$smoke_dir/studio.log"
    exit 1
  fi
  sleep 1
done
[[ "$studio_status" == 200 ]] || {
  printf 'error: Open Design Studio did not return HTTP 200\n' >&2
  exit 1
}
printf 'Open Design Studio smoke passed: HTTP %s\n' "$studio_status"

bash scripts/hyperframes.sh doctor
bash scripts/hyperframes.sh init "$smoke_dir/composition" \
  --non-interactive --example=blank
bash scripts/hyperframes.sh lint "$smoke_dir/composition"
bash scripts/hyperframes.sh render "$smoke_dir/composition" \
  --output "$smoke_dir/composition/smoke.mp4"

ffprobe -v error \
  -select_streams v:0 \
  -show_entries stream=codec_name,width,height \
  -of default=noprint_wrappers=1 \
  "$smoke_dir/composition/smoke.mp4"

python3 scripts/open-design-mcp-smoke.py
