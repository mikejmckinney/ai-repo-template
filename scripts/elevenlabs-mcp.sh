#!/usr/bin/env bash
set -euo pipefail

: "${ELEVENLABS_API_KEY:?ELEVENLABS_API_KEY is required}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

export ELEVENLABS_MCP_BASE_PATH="$REPO_ROOT/.artifacts/audio"
export ELEVENLABS_MCP_OUTPUT_MODE="files"
mkdir -p "$ELEVENLABS_MCP_BASE_PATH"

exec uvx --python 3.13 elevenlabs-mcp==0.11.0
