#!/bin/bash
# 50-ensure-variables.sh — Set repo-level variables consumed by the pipeline.
#
# Sourced by scripts/setup.sh AFTER 40-ensure-labels.sh, which performs the
# gh-auth pre-flight and exports GH_REPO. This module no-ops cleanly when the
# pre-flight requested a skip or no FULL_REPO target was resolved.

# Skip when 40-ensure-labels.sh decided to bail out (Codespaces token /
# missing repo target / gh not authenticated). The remediation block was
# already printed; do not duplicate it here.
if [[ -n "${_pipeline_setup_skip_reason:-}" ]] \
  || [[ -z "${_gh_auth_ok:-}" ]] \
  || [[ -z "${FULL_REPO:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

# Budget knobs for agent-assign-copilot.yml. Only set if missing so a
# re-run of setup.sh doesn't clobber tuned values. `gh variable get` is
# used instead of `gh variable list | grep` to avoid pagination limits.
_ensure_variable() {
  local name="$1" value="$2" err first_err
  if gh variable get "$name" &>/dev/null; then
    log_info "$name already set (leaving as-is)"
    return 0
  fi
  if err=$(gh variable set "$name" --body "$value" 2>&1 >/dev/null); then
    log_info "Set $name=$value"
  else
    first_err=$(printf '%s\n' "$err" | grep -v '^$' | head -n1)
    log_warn "Could not set $name — ${first_err:-unknown error}. Set it manually to $value if needed."
  fi
}
_ensure_variable MAX_COPILOT_CONCURRENT 3
# One-time migration: old default was 20; new default is 10 (phase-1 cost mitigation).
# Gated on MAX_COPILOT_DAILY_MIGRATED_V1 so setup.sh is idempotent — if a maintainer
# deliberately restores MAX_COPILOT_DAILY=20 after the initial migration, subsequent
# setup.sh reruns will see the marker is already set and skip, preserving the choice.
if [[ "$(gh variable get MAX_COPILOT_DAILY 2>/dev/null)" == "20" ]] \
  && [[ "$(gh variable get MAX_COPILOT_DAILY_MIGRATED_V1 2>/dev/null)" != "true" ]]; then
  if gh variable set MAX_COPILOT_DAILY --body "10" 2>/dev/null; then
    gh variable set MAX_COPILOT_DAILY_MIGRATED_V1 --body "true" 2>/dev/null \
      || log_warn "Could not set MAX_COPILOT_DAILY_MIGRATED_V1 marker — if MAX_COPILOT_DAILY is restored to 20, re-running setup.sh may re-migrate. Set manually: gh variable set MAX_COPILOT_DAILY_MIGRATED_V1 --body true"
    log_warn "Migrated MAX_COPILOT_DAILY 20 → 10 (phase-1 cost-mitigation default). If 20 was intentional, restore it: gh variable set MAX_COPILOT_DAILY --body 20"
  else
    log_warn "Could not migrate MAX_COPILOT_DAILY — set it manually to 10 if desired."
  fi
fi
_ensure_variable MAX_COPILOT_DAILY 10
# Ensure the migration marker is set for ALL installs (including fresh ones that
# never entered the migration block above). Without this, repos seeded with
# MAX_COPILOT_DAILY=10 by _ensure_variable have no marker, so a maintainer who
# later intentionally sets the value to 20 would have it silently forced back
# to 10 on the next setup.sh run.
_ensure_variable MAX_COPILOT_DAILY_MIGRATED_V1 "true"
_ensure_variable PR_RESOLVE_MAX_ROUNDS 3

# REVIEW_ON_PUSH (issue #205): opt-out toggle for agent-review-on-push.yml,
# which nudges Gemini (`/gemini review` comment under CLAUDE_PAT) and
# Copilot (re-request via GraphQL `requestReviewsByLogin` mutation with
# `botLogins: ["copilot-pull-request-reviewer[bot]"]`) after each push
# to an open non-draft PR. Earlier attempts (REST `requested_reviewers`,
# GraphQL `requestReviews` with Bot node ID) all silently no-op'd or
# returned HTTP 422 — only `requestReviewsByLogin` exposes a `botLogins`
# field that actually fires Copilot review.
# Default ON: leaving the variable unset = on is the desired default.
# Opt out with:
#   gh variable set REVIEW_ON_PUSH --body false
# To re-enable:
#   gh variable delete REVIEW_ON_PUSH
