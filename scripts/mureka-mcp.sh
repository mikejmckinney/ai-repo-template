#!/usr/bin/env bash
set -euo pipefail

: "${MUREKA_API_KEY:?MUREKA_API_KEY is required}"

export MUREKA_API_URL="${MUREKA_API_URL:-https://api.mureka.ai}"
export TIME_OUT_SECONDS="${TIME_OUT_SECONDS:-300}"

exec uvx --python 3.13 mureka-mcp==0.0.13
