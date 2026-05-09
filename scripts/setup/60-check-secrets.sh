#!/bin/bash
# 60-check-secrets.sh — Report which required pipeline secrets are present.
#
# Sourced by scripts/setup.sh AFTER 40/50. No-ops cleanly when the gh-auth
# pre-flight in 40-ensure-labels.sh requested a skip.
#
# Companion to the per-workflow `Verify required secrets` guard
# steps (see issue #162). Reports which required secrets are
# available to this repo via gh's API. Cannot read secret VALUES
# (GitHub never returns them), only their presence.
#
# Visibility tiers checked, in order:
#   1. Repo-level secrets (`gh secret list`, requires admin scope)
#   2. Org-level secrets visible to this repo
#      (`gh api /repos/{owner}/{repo}/actions/organization-secrets`,
#      requires read scope on the org)
#
# Both calls degrade to "unknown" on permission errors rather than
# failing the script — the workflows themselves enforce presence at
# runtime via the guard steps.

if [[ -n "${_pipeline_setup_skip_reason:-}" ]] \
  || [[ -z "${_gh_auth_ok:-}" ]] \
  || [[ -z "${FULL_REPO:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

log_step "Checking required pipeline secrets"
_required_secrets=(CLAUDE_PAT ANTHROPIC_API_KEY)
_repo_secrets=""
_org_secrets=""
if _repo_secrets=$(gh secret list --limit 100 --json name --jq '.[].name' 2>/dev/null); then
  :
else
  log_warn "Could not list repo secrets (gh secret list returned non-zero)."
  log_warn "  This usually means the running token lacks repo admin scope."
  log_warn "  Skipping repo-secret presence check; org-level still attempted."
  _repo_secrets="__unknown__"
fi
# Extract owner/repo (strip host prefix if present for GitHub Enterprise)
_repo_path="${FULL_REPO#*/}"                          # Remove host if format is host/owner/repo
[[ "$_repo_path" == */* ]] || _repo_path="$FULL_REPO" # Use original if no host
if _org_secrets=$(gh api "/repos/${_repo_path}/actions/organization-secrets?per_page=100" \
  --jq '.secrets[].name' 2>/dev/null); then
  :
else
  # Personal repos don't have org secrets, or token lacks permission.
  # Set to special marker to distinguish "no secrets" from "query failed".
  _org_secrets="__unknown__"
fi
for _secret in "${_required_secrets[@]}"; do
  if [[ "$_repo_secrets" != "__unknown__" ]] \
    && printf '%s\n' "$_repo_secrets" | grep -qx "$_secret"; then
    log_info "  $_secret — present (repo-level)"
  elif [[ "$_org_secrets" != "__unknown__" ]] \
    && printf '%s\n' "$_org_secrets" | grep -qx "$_secret"; then
    log_info "  $_secret — present (org-level, granted to this repo)"
  elif [[ "$_repo_secrets" == "__unknown__" || "$_org_secrets" == "__unknown__" ]]; then
    log_warn "  $_secret — presence unknown (could not query). If workflows fail with"
    log_warn "             'Missing required secret: $_secret', add it via either:"
    log_warn "             Per-repo: Settings → Secrets and variables → Actions"
    log_warn "             Org-wide: Org settings → Secrets and variables → Actions (then grant this repo)"
  else
    log_warn "  $_secret — MISSING. Workflows depending on it will fail fast at runtime."
    log_warn "             Per-repo: Settings → Secrets and variables → Actions → New repository secret"
    log_warn "             Org-wide: Org settings → Secrets and variables → Actions → New organization secret"
    log_warn "             See docs/guides/agent-pipeline.md → Required secrets for required PAT scopes."
  fi
done
