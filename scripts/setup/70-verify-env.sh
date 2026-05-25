#!/bin/bash
# 70-verify-env.sh — Run scripts/verify-env.sh as the final setup gate.

log_step "Verifying environment"

if [[ -f "scripts/verify-env.sh" ]]; then
  ./scripts/verify-env.sh --fix
else
  log_warn "verify-env.sh not found, skipping verification"
fi
