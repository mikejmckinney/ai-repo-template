#!/usr/bin/env bash
# Dispatch daily retro by execution mode (sequential | monolithic | parallel).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${POSTMERGE_RETRO_EXECUTION_MODE:-sequential}"

case "$MODE" in
  sequential | a | arm_a)
    exec bash "$SCRIPT_DIR/run-postmerge-retro-daily.sh"
    ;;
  monolithic | b | arm_b)
    exec bash "$SCRIPT_DIR/run-postmerge-retro-monolithic.sh"
    ;;
  parallel | c | arm_c)
    exec bash "$SCRIPT_DIR/run-postmerge-retro-parallel.sh"
    ;;
  *)
    echo "::error::Unknown POSTMERGE_RETRO_EXECUTION_MODE=${MODE} (use sequential, monolithic, or parallel)" >&2
    exit 1
    ;;
esac
