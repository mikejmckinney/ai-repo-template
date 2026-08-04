#!/usr/bin/env bash
set -Eeuo pipefail

readonly hyperframes_version="0.7.90"

if [[ "${1:-}" == "--print-version-pin" ]]; then
  printf '%s\n' "$hyperframes_version"
  exit 0
fi

command -v node >/dev/null 2>&1 || {
  printf 'error: Node.js is required\n' >&2
  exit 1
}

node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if ((node_major < 22)); then
  printf 'error: HyperFrames requires Node.js 22 or newer (found %s)\n' "$(node --version)" >&2
  exit 1
fi

command -v ffmpeg >/dev/null 2>&1 || {
  printf 'error: ffmpeg is required\n' >&2
  exit 1
}

# Repository skills are pinned and hashed; never install mutable global copies.
export HYPERFRAMES_SKIP_SKILLS=1

exec npx -y "hyperframes@${hyperframes_version}" "$@"
