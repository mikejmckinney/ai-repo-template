#!/usr/bin/env bash
set -euo pipefail

: "${ACEDATACLOUD_API_TOKEN:?ACEDATACLOUD_API_TOKEN is required}"

exec uvx --python 3.13 --with "mcp==1.29.0" mcp-suno==2026.7.4.0
