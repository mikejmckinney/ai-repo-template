#!/usr/bin/env bash
# scripts/workflows/lib/fix-phase-log.sh — phase duration notices for fix jobs.
#
# Usage (after source):
#   fix_phase_log_init
#   fix_phase_log "checkout"
#   fix_phase_log "llm-fix"

fix_phase_log_init() {
  FIX_PHASE_START=$(date +%s)
}

fix_phase_log() {
  local label="${1:-unknown}"
  local now elapsed
  now=$(date +%s)
  elapsed=$((now - FIX_PHASE_START))
  echo "::notice::fix-phase=${label} elapsed_s=${elapsed}"
  FIX_PHASE_START=$now
}
