#!/bin/bash
# 40-ensure-labels.sh — Probe gh auth + create the pipeline labels.
#
# Sourced by scripts/setup.sh AFTER 00-detect-repo.sh (needs FULL_REPO).
#
# Sets these shared variables for 50-ensure-variables.sh / 60-check-secrets.sh:
#   _pipeline_setup_skip_reason  — non-empty when Step 5/6 should skip
#   _gh_auth_ok                  — "true" when gh auth status succeeded
#   FULL_REPO                    — possibly upgraded via `gh repo view` fallback
#   GH_REPO                      — exported so downstream gh calls inherit scope
#
# All labels created here are documented in docs/guides/agent-pipeline.md.

# Labels and budget knobs consumed by the autonomous agent pipeline (see
# docs/guides/agent-pipeline.md). Safe to re-run: `gh label
# create` returns non-zero when a label already exists, which we swallow.
# Requires `gh auth login` first; otherwise the whole step is skipped.
log_step "Configuring pipeline labels and repo variables"

_PIPELINE_LABEL_SPECS=$(
  cat <<'LABEL_SPECS'
auto-merge|0E8A16|Enable auto-merge workflow for this PR
auto-merge-fast|1D76DB|Bypass auto-merge bot-review settle wait for this PR
agent-complete|0E8A16|PR merged and linked issue closed
no-auto-ready|BFDADC|Opt out of automatic ready-state handling
claude-fix|FBCA04|Opt PR in to agent-fix-reviews.yml (Claude resolution)
claude-review|1D76DB|Opt PR in to claude.yml auto-review (invokes judge subagent)
copilot-relay|5319E7|Opt PR in to agent-relay-reviews.yml (Copilot resolution; included in subscription)
smoke-test|E99695|Workflow-validation PR; auto-merge/relay/fix-reviews skip to avoid mid-test interference
copilot:ready|0E8A16|Assign Copilot when budget allows
copilot:in-progress|1D76DB|Assigned to Copilot, counts toward concurrent budget
copilot:queued|FBCA04|Waiting for an open Copilot slot
copilot:budget-paused|E4E669|90% daily spend threshold hit; not auto-drained; add cap-override + copilot:ready to resume
copilot:daily-cap-hit|D93F0B|Hit daily assignment cap; manual re-queue required
from-backlog|5319E7|Issue auto-created from .context/backlog.yaml
needs-human|B60205|Requires human input (e.g., empty roadmap phase, CI failure)
agent:claimed|0969DA|Agent has claimed the issue or PR; details live in the latest agent-state:v1 comment
agent:blocked|D93F0B|Agent work is blocked; details live in the latest agent-state:v1 comment
agent:awaiting-review|F29513|Agent work is awaiting review; details live in the latest agent-state:v1 comment
chore:no-plan|EDEDED|Exempt this issue/PR from the plan-as-comment requirement (ADR-011)
outcome-validated|0E8A16|Issue author has validated the user outcome inline; opts out of Analyst pre-flight gate (ADR-005, ADR-014)
cap-override|FBCA04|Bypass max-round cap (pr-resolve-all.md) and 90% daily spend pause (agent-assign-copilot.yml)
agent-suggested|BFD4F2|Agent-surfaced opportunity; see process_opportunity_feedback rule.
LABEL_SPECS
)
_PIPELINE_LABELS=$(printf '%s\n' "$_PIPELINE_LABEL_SPECS" | awk -F'|' 'NF { printf "%s%s", sep, $1; sep=", " } END { print "" }')
_SETUP_VARIABLES_FILE="${SCRIPT_DIR:-scripts}/setup/50-ensure-variables.sh"
_PIPELINE_VARIABLES=$(
  awk '
    /^[[:space:]]*_ensure_variable (MAX_COPILOT_CONCURRENT|MAX_COPILOT_DAILY|PR_RESOLVE_MAX_ROUNDS) / {
      value = $3
      gsub(/^"|"$/, "", value)
      printf "%s%s=%s", sep, $2, value
      sep = ", "
    }
    END { print "" }
  ' "$_SETUP_VARIABLES_FILE"
)
_PIPELINE_LABEL_LIST_LIMIT="${PIPELINE_LABEL_LIST_LIMIT:-200}"

# Pre-flight: detect the Codespaces auto-injected GITHUB_TOKEN case. That
# token is scoped to `contents:write, metadata:read` by default, which means
# every `gh label create` (needs `issues:write`) and every `gh variable set`
# (needs admin) will 403. Rather than spam ~13 warnings, print one clear
# remediation block and skip Step 5.
#
# If the user has set a Codespaces user secret named GH_PAT (or one of the
# common aliases), prefer it: unset GITHUB_TOKEN and `gh auth login --with-token`
# so subsequent gh calls use the elevated PAT automatically. Recommended PAT:
# fine-grained, scoped to this repo, with Issues + Variables + Contents +
# Metadata + Pull requests = read/write, and Workflows = read/write if you
# edit workflows. Set it once at https://github.com/settings/codespaces.
_pipeline_setup_skip_reason=""
_gh_auth_ok=""
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  _gh_auth_ok="true"
  # Only treat the `(GITHUB_TOKEN)` auth source as the Codespaces-limited
  # case when we're actually running inside a Codespace (`CODESPACES=true`).
  # In GitHub Actions or when a user has set `GITHUB_TOKEN` manually, the
  # same auth-source string shows up but the remediation below (Codespaces
  # user secret) doesn't apply — fall through to the normal per-command
  # error reporting instead.
  # `gh auth status` writes the token-source line to stderr.
  if [[ "${CODESPACES:-}" == "true" ]] \
    && gh auth status 2>&1 | grep -qE 'Logged in to github\.com.*\(GITHUB_TOKEN\)'; then
    # Try to upgrade auth using a Codespaces user secret if one is set.
    _user_pat=""
    for _var in GH_PAT GH_TOKEN_PAT CODESPACES_GH_PAT GITHUB_PAT; do
      if [[ -n "${!_var:-}" ]]; then
        _user_pat="${!_var}"
        _user_pat_var="$_var"
        break
      fi
    done
    if [[ -n "$_user_pat" ]]; then
      log_info "Found Codespaces secret \$$_user_pat_var; logging gh in with it."
      unset GITHUB_TOKEN
      if printf '%s' "$_user_pat" | gh auth login --with-token 2>/dev/null; then
        log_info "gh re-authenticated with \$$_user_pat_var"
      else
        log_warn "Failed to authenticate gh with \$$_user_pat_var; falling back to skip."
      fi
      unset _user_pat
    fi

    # Re-probe permission after potential upgrade. Only skip when the
    # probe succeeds AND explicitly returns "false" (token is
    # authenticated against the repo but lacks admin). If the probe
    # errors or returns empty (network blip, repo not found, jq miss),
    # fall through so per-command errors get surfaced rather than
    # silently swallowed behind the remediation block.
    _repo_admin=$(gh api "repos/{owner}/{repo}" --jq '.permissions.admin' 2>/dev/null || echo "")
    if [[ "$_repo_admin" == "false" ]]; then
      _pipeline_setup_skip_reason="codespaces-token"
    fi
  fi
fi

if [[ -n "$_pipeline_setup_skip_reason" ]]; then
  log_warn "gh is using the Codespaces-injected GITHUB_TOKEN, which lacks 'issues:write' and admin scopes."
  log_warn "Skipping label/variable creation to avoid noisy 403 errors."
  log_warn "Recommended (one-time setup, auto-applies to every future Codespace):"
  log_warn "  1) Create a fine-grained PAT: https://github.com/settings/personal-access-tokens/new"
  log_warn "     Repo permissions: Issues r/w, Variables r/w, Contents r/w, Metadata r, Pull requests r/w, Workflows r/w"
  log_warn "  2) Add as a Codespaces user secret named GH_PAT: https://github.com/settings/codespaces"
  log_warn "     Grant it access to this repo, then rebuild the Codespace (or re-run setup.sh in a new one)."
  log_warn "Ad-hoc alternative (current Codespace only):"
  log_warn "  unset GITHUB_TOKEN && gh auth login -s repo,workflow && ./scripts/setup.sh"
  log_warn "Or create the following manually:"
  log_warn "  Labels: $_PIPELINE_LABELS"
  log_warn "  Variables: $_PIPELINE_VARIABLES"
elif [[ -n "$_gh_auth_ok" ]]; then
  # Last-resort FULL_REPO fallback: if Step 0 couldn't parse a remote and
  # no env override was provided, ask gh itself. This works when gh has
  # been authenticated against a repo via some out-of-band mechanism
  # (e.g., default repo set via `gh repo set-default`).
  if [[ -z "$FULL_REPO" ]]; then
    _repo_nwo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
    if [[ -n "$_repo_nwo" ]]; then
      # Prefix with GH_HOST for GHES / multi-host setups so the exported
      # GH_REPO value resolves against the correct GitHub instance.
      if [[ -n "${GH_HOST:-}" ]]; then
        FULL_REPO="${GH_HOST}/${_repo_nwo}"
      else
        FULL_REPO="$_repo_nwo"
      fi
      log_info "Resolved repository from gh: $FULL_REPO"
    fi
  fi

  # If we still don't know which repo to target, every `gh label`/`gh
  # variable` call below would emit the raw "no git remotes found" error.
  # Surface one consolidated remediation block instead.
  if [[ -z "$FULL_REPO" ]]; then
    log_warn "No GitHub repo target found; cannot create labels/variables."
    log_warn "Cause: no 'origin' git remote, and neither GH_REPO nor GITHUB_REPOSITORY is set."
    log_warn "Pick one:"
    log_warn "  a) Add a remote, then re-run:"
    log_warn "       git remote add origin https://github.com/<owner>/<repo>.git"
    log_warn "       ./scripts/setup.sh"
    log_warn "  b) One-shot override:"
    log_warn "       GH_REPO=<owner>/<repo> ./scripts/setup.sh"
    log_warn "Or create the following manually in the GitHub UI:"
    log_warn "  Labels: $_PIPELINE_LABELS"
    log_warn "  Variables: $_PIPELINE_VARIABLES"
  else
    # Scope every `gh` call in this block to FULL_REPO. gh respects
    # GH_REPO as the "default repo" override, which avoids having to
    # thread `--repo "$FULL_REPO"` through each helper.
    export GH_REPO="$FULL_REPO"
    log_info "Targeting $FULL_REPO for label/variable creation"
    _existing_pipeline_labels=$(gh label list --limit "$_PIPELINE_LABEL_LIST_LIMIT" --json name --jq '.[].name') \
      || _existing_pipeline_labels=""

    _pipeline_label_exists() {
      local name="$1"
      printf '%s\n' "$_existing_pipeline_labels" | grep -qxF "$name"
    }

    _pipeline_label_cache_add() {
      local name="$1"
      _existing_pipeline_labels=$(printf '%s\n%s\n' "$_existing_pipeline_labels" "$name")
    }

    # Helper: create a label idempotently, surfacing real failures.
    # `gh label create` exits non-zero for both "already exists" and real errors;
    # check existence on failure so genuine permission/API errors aren't swallowed.
    # Capture stderr so the WARN includes the actual gh/API error message.
    _ensure_label() {
      local name="$1" color="$2" desc="$3" err first_err
      if _pipeline_label_exists "$name"; then
        return 0
      fi
      if err=$(gh label create "$name" --color "$color" --description "$desc" 2>&1 >/dev/null); then
        _pipeline_label_cache_add "$name"
        return 0
      fi
      first_err=$(printf '%s\n' "$err" | grep -v '^$' | head -n1)
      log_warn "Could not create label '$name' — ${first_err:-unknown error}"
    }

    # Create every pipeline label surfaced in docs/guides/agent-pipeline.md's
    # label table so the doc's "created automatically by setup.sh" claim
    # is literally true. The pipe-delimited specs above are the local
    # manifest for name/color/description; warnings and creation calls are
    # generated from the same rows to avoid label-list drift.
    while IFS='|' read -r name color desc; do
      [[ -z "$name" ]] && continue
      _ensure_label "$name" "$color" "$desc"
    done <<<"$_PIPELINE_LABEL_SPECS"
    log_info "Pipeline labels ensured ($_PIPELINE_LABELS)"
  fi
else
  log_warn "gh CLI not authenticated; skipping label/variable creation."
  log_warn "After running 'gh auth login', re-run scripts/setup.sh, or create the following manually:"
  log_warn "  Labels: $_PIPELINE_LABELS"
  log_warn "  Variables: $_PIPELINE_VARIABLES"
fi
