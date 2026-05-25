#!/usr/bin/env bash
# scripts/diag-sandbox.sh — read-only sandbox auth/access doctor (issue #365).
#
# Diagnoses sandbox auth source, reachability, and stale test branch readiness.
# Makes NO writes, force-pushes, branch deletions, or remote modifications of
# any kind. Safe to run at any time without side effects.
#
# Usage:
#   ./scripts/diag-sandbox.sh
#
# Exit codes:
#   0 — all checks passed; sandbox appears reachable with usable auth
#   1 — hard failure (script logic error or auth configuration is broken)
#   2 — warning-level: sandbox unreachable or sandbox remote not configured
#
# Environment knobs:
#   SANDBOX_REMOTE     Local git remote name for the sandbox (default: sandbox).
#   DIAG_GIT_TIMEOUT   Integer seconds for git ls-remote probe timeout.
#                      Default: 10. Set to 0 to skip timeout wrapper.
#
# Auth-source detection uses the same PAT variable probe list
# (GH_PAT, GH_TOKEN_PAT, CODESPACES_GH_PAT, GITHUB_PAT) as
# scripts/setup/40-ensure-labels.sh.
# Both files must be updated together if new PAT aliases are added.
# Intentionally omits `set -e`: this is a diagnostic script, so it keeps
# collecting explicit checks and uses targeted exits for hard-failure paths.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

require_tool() {
  local tool="$1"
  if ! command -v "$tool" &>/dev/null; then
    log_error "$tool is required but not installed"
    exit 1
  fi
}

_redact_remote_text() {
  printf '%s' "$1" | sed -E 's#(https?://)[^/@[:space:]]+@#\1***@#g'
}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SANDBOX_REMOTE="${SANDBOX_REMOTE:-sandbox}"
# PAT probe list — must match scripts/setup/40-ensure-labels.sh.
_PAT_VARS=(GH_PAT GH_TOKEN_PAT CODESPACES_GH_PAT GITHUB_PAT)

echo "========================================"
echo "Sandbox Doctor"
echo "========================================"
echo ""

require_tool gh
require_tool git

# ---------------------------------------------------------------------------
# 1. Auth-source detection
# ---------------------------------------------------------------------------
echo "Checking auth source..."

_pat_found=""
_pat_var_found=""
_auth_exit=0
_auth_output=$(gh auth status 2>&1) || _auth_exit=$?
_identity=$(printf '%s' "$_auth_output" | grep -E 'Logged in to' | head -1 || true)

if [[ "$_auth_exit" -ne 0 && -z "$_identity" ]]; then
  log_error "gh auth status failed — gh may not be authenticated"
  log_error "Run: gh auth login"
  exit 1
fi

if [[ "${CODESPACES:-}" == "true" ]]; then
  log_info "Running inside Codespaces"

  # Detect the injected GITHUB_TOKEN auth-source pattern.
  if printf '%s' "$_auth_output" | grep -qE 'Logged in to github\.com.*\(GITHUB_TOKEN\)'; then
    log_warn "gh is authenticated via GITHUB_TOKEN (injected by Codespaces)"
    log_warn "This token may lack sandbox repo write access — probing for PAT upgrade..."

    for _var in "${_PAT_VARS[@]}"; do
      if [[ -n "${!_var:-}" ]]; then
        _pat_found="${!_var}"
        _pat_var_found="$_var"
        break
      fi
    done

    if [[ -n "$_pat_found" ]]; then
      log_info "PAT upgrade available: \$$_pat_var_found is set"
      log_info "To activate: unset GITHUB_TOKEN && printf '%s' \"\$$_pat_var_found\" | gh auth login --with-token"
    else
      log_warn "No PAT variable found (checked: ${_PAT_VARS[*]})"
      log_warn "Sandbox commands requiring write access will fail with the Codespaces GITHUB_TOKEN"
      log_warn "Set one of: ${_PAT_VARS[*]} as a Codespaces user secret"
    fi
  else
    if [[ -n "$_identity" ]]; then
      # Codespaces with an explicit non-GITHUB_TOKEN auth-source — PAT already active.
      log_info "gh auth active (non-GITHUB_TOKEN): ${_identity}"
    else
      log_warn "gh auth status returned no identity — gh may not be authenticated"
      log_warn "Run: gh auth login"
    fi
  fi
else
  # Outside Codespaces: report active identity and token source.
  log_info "Not running in Codespaces"
  _token_source=$(printf '%s' "$_auth_output" | grep -E 'Token:' | head -1 || true)

  if [[ -n "$_identity" ]]; then
    log_info "gh identity: ${_identity}"
    [[ -n "$_token_source" ]] && log_info "Token source: ${_token_source}"
  else
    log_warn "gh auth status returned no identity — gh may not be authenticated"
    log_warn "Run: gh auth login"
  fi

  # Outside Codespaces: also check for PAT variables (optional upgrade path).
  for _var in "${_PAT_VARS[@]}"; do
    if [[ -n "${!_var:-}" ]]; then
      _pat_found="${!_var}"
      _pat_var_found="$_var"
      break
    fi
  done
  if [[ -n "$_pat_found" ]]; then
    log_info "PAT variable available: \$$_pat_var_found"
  fi
fi

unset _var _pat_found _pat_var_found _identity _token_source _auth_output _auth_exit || true

echo ""

# ---------------------------------------------------------------------------
# 2. Sandbox remote reachability
# ---------------------------------------------------------------------------
echo "Checking sandbox remote reachability..."

if ! git rev-parse --git-dir &>/dev/null; then
  log_error "Current directory is not a git repository"
  log_error "Run this doctor from inside a git checkout with the sandbox remote configured"
  exit 1
fi

# Resolve the sandbox remote URL.
_sandbox_url=""
if ! _sandbox_url=$(git remote get-url "$SANDBOX_REMOTE" 2>/dev/null); then
  log_warn "Sandbox remote '$SANDBOX_REMOTE' is not configured"
  log_warn "Advisory: run 'git remote add $SANDBOX_REMOTE <sandbox-repo-url>' to configure it"
  log_warn "  or: run ./scripts/sandbox-bootstrap.sh for one-time sandbox setup"
  exit 2
fi

log_info "Sandbox remote '$SANDBOX_REMOTE': $(_redact_remote_text "$_sandbox_url")"

# Probe reachability with a timeout-wrapped git ls-remote (read-only).
_ls_remote_output=""
_ls_remote_exit=0
_timeout_val="${DIAG_GIT_TIMEOUT:-10}"

if [[ "$_timeout_val" == "0" ]]; then
  _ls_remote_output=$(git ls-remote "$_sandbox_url" 'refs/heads/*' 2>&1) || _ls_remote_exit=$?
  if [[ "$_ls_remote_exit" -ne 0 ]]; then
    log_warn "git ls-remote failed (exit $_ls_remote_exit) — sandbox may not be accessible with current auth"
    log_warn "Output: $(_redact_remote_text "$_ls_remote_output")"
    exit 2
  fi
elif command -v timeout &>/dev/null; then
  _ls_remote_output=$(timeout "$_timeout_val" git ls-remote "$_sandbox_url" 'refs/heads/*' 2>&1) || _ls_remote_exit=$?
  if [[ "$_ls_remote_exit" -ne 0 ]]; then
    if [[ "$_ls_remote_exit" -eq 124 ]]; then
      log_warn "sandbox remote unreachable (timed out after ${_timeout_val}s)"
      log_warn "Set DIAG_GIT_TIMEOUT=<seconds> to override the default 10s timeout"
      exit 2
    else
      log_warn "git ls-remote failed (exit $_ls_remote_exit) — sandbox may not be accessible with current auth"
      log_warn "Output: $(_redact_remote_text "$_ls_remote_output")"
      exit 2
    fi
  fi
else
  log_warn "timeout command unavailable — git ls-remote timeout unenforced"
  _ls_remote_output=$(git ls-remote "$_sandbox_url" 'refs/heads/*' 2>&1) || _ls_remote_exit=$?
  if [[ "$_ls_remote_exit" -ne 0 ]]; then
    log_warn "git ls-remote failed (exit $_ls_remote_exit) — sandbox may not be accessible"
    log_warn "Output: $(_redact_remote_text "$_ls_remote_output")"
    exit 2
  fi
fi

log_info "Sandbox remote is reachable"
echo ""

# ---------------------------------------------------------------------------
# 3. Stale test branch reporting
# ---------------------------------------------------------------------------
echo "Checking sandbox branches..."

_branch_count=$(printf '%s\n' "$_ls_remote_output" | grep -v '^$' | wc -l | tr -d ' ')
log_info "Found $_branch_count branch(es) on sandbox remote"

# Report non-main branches as potentially stale test branches.
_non_main=$(printf '%s\n' "$_ls_remote_output" | grep -v 'refs/heads/main$' | grep -v '^$' || true)
if [[ -n "$_non_main" ]]; then
  log_warn "Non-main branches found (may be stale test branches):"
  while IFS= read -r _branch_line; do
    [[ -z "$_branch_line" ]] && continue
    log_warn "  $_branch_line"
  done <<<"$_non_main"
else
  if [[ "$_branch_count" -eq 0 ]]; then
    log_info "No branches found on sandbox remote"
  else
    log_info "No stale branches detected (only main branch exists)"
  fi
fi

unset _sandbox_url _ls_remote_output _ls_remote_exit _timeout_val \
  _branch_count _non_main _branch_line || true

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================"
echo "Sandbox Doctor: PASS"
echo "========================================"
exit 0
