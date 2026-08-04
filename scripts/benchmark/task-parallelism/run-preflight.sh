#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
REPORT_PATH="${REPO_ROOT}/.artifacts/task-parallelism/preflight-report.json"
SAFE_PATH="/usr/local/bin:/usr/bin:/bin"

if ! command -v unshare >/dev/null 2>&1; then
  echo "task-parallelism preflight: unshare is required" >&2
  exit 2
fi

if ! unshare -Urn true 2>/dev/null; then
  echo "task-parallelism preflight: unshare -Urn is unavailable" >&2
  exit 2
fi

python3 - <<'PY'
import importlib.metadata

version = importlib.metadata.version("jsonschema")
if version != "4.26.0":
    raise SystemExit(f"task-parallelism preflight: jsonschema 4.26.0 required, found {version}")
PY

ffmpeg_version="$(ffmpeg -version 2>/dev/null | awk 'NR == 1 { print $3; exit }')"
if [[ "${ffmpeg_version}" != "6.1.1-3ubuntu5" ]]; then
  echo "task-parallelism preflight: ffmpeg 6.1.1-3ubuntu5 required, found ${ffmpeg_version:-missing}" >&2
  exit 2
fi

mkdir -p "$(dirname "${REPORT_PATH}")"

exec env -i \
  HOME="${HOME}" \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  PATH="${SAFE_PATH}" \
  PYTHONDONTWRITEBYTECODE=1 \
  REPO_ROOT="${REPO_ROOT}" \
  REPORT_PATH="${REPORT_PATH}" \
  TMPDIR="${TMPDIR:-/tmp}" \
  unshare -Urn --map-root-user \
  python3 -P "${SCRIPT_DIR}/preflight_launcher.py" "$@"
