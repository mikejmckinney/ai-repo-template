#!/bin/bash
# 10-env-file.sh — Bootstrap .env from .env.example.
#
# Sourced by scripts/setup.sh. Idempotent: never overwrites an existing .env.

log_step "Setting up environment variables"

if [[ -f ".env" ]]; then
  log_info ".env already exists, skipping"
elif [[ -f ".env.example" ]]; then
  cp .env.example .env
  log_info "Created .env from .env.example"
  log_warn "Review .env and update any placeholder values"
else
  log_warn "No .env.example found, skipping environment setup"
fi
