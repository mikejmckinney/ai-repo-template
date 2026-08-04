#!/usr/bin/env bash
# scripts/codespace-post-start.sh — non-fatal Codespace post-start hook.
#
# Invoked by .devcontainer/devcontainer.json whenever the container starts.
# Upgrades gh from the injected GITHUB_TOKEN to a Codespaces user PAT when
# available, exports session tokens for sandbox git/gh, and ensures the
# sandbox git remote exists (same defaults as sandbox-bootstrap.sh).
#
# Does NOT run sandbox-bootstrap.sh because repository creation and mirroring
# require an explicit maintainer action.
#
# Usage (from repo root):
#   ./scripts/codespace-post-start.sh
#
# Exit 0 always — failures are logged as warnings so Codespace creation is not blocked.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CODESPACE_POST_START_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=scripts/lib/ensure-gh-pat-auth.sh
source "$SCRIPT_DIR/lib/ensure-gh-pat-auth.sh"
# shellcheck source=scripts/lib/sandbox-remote.sh
source "$SCRIPT_DIR/lib/sandbox-remote.sh"

if [[ "${CODESPACES:-}" != "true" ]]; then
  log_info "Not a Codespace; skipping codespace-post-start."
  exit 0
fi

log_step "Codespace post-start (gh PAT auth + sandbox remote)"

ensure_gh_pat_auth

if [[ "${ENSURE_GH_PAT_AUTH_UPGRADED:-false}" == "true" ]]; then
  log_info "gh re-authenticated with \$${ENSURE_GH_PAT_AUTH_VAR}."
  apply_gh_pat_session_exports || true
  install_codespace_shell_auth_hook
  log_info "Installed shell hook: ~/.config/ai-repo-template/codespace-auth.sh"
elif [[ "${ENSURE_GH_PAT_AUTH_LIMITED:-false}" == "true" ]]; then
  log_warn "gh is using the Codespaces-injected GITHUB_TOKEN (limited to current repo)."
  log_warn "Add GH_PAT as a Codespaces user secret: https://github.com/settings/codespaces"
  log_warn "Use a fine-grained PAT restricted to the upstream and sandbox repositories."
  log_warn "Grant Issues, Variables, Contents, and Pull requests R/W; Metadata R; Workflows R/W if needed."
  log_warn "Classic repo + workflow scopes are a broader fallback covering every accessible repository."
else
  log_info "gh auth does not need PAT upgrade (or gh is not authenticated)."
fi

repo_visibility="$({
  cd "$REPO_ROOT" || exit
  gh repo view --json visibility --jq .visibility 2>/dev/null || true
})"
if [[ "${repo_visibility^^}" != "PRIVATE" ]]; then
  if [[ -n "$repo_visibility" ]]; then
    log_warn "Repository is not private; skipping automatic OpenCode OAuth synchronization."
  else
    log_warn "Repository visibility could not be verified; skipping automatic OpenCode OAuth synchronization."
  fi
elif (cd "$REPO_ROOT" && "$SCRIPT_DIR/sync-opencode-oauth-secret.sh" --apply); then
  log_info "OpenCode OAuth access synchronized to Actions."
else
  log_warn "OpenCode OAuth access synchronization failed; hosted workflows will use their configured fallback provider."
fi

if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  sandbox_ensure_git_remote "$REPO_ROOT" || true
  if git -C "$REPO_ROOT" remote get-url "${SANDBOX_REMOTE:-sandbox}" &>/dev/null; then
    if [[ -x "$REPO_ROOT/scripts/diag-sandbox.sh" ]]; then
      log_info "Running sandbox doctor (read-only)..."
      (cd "$REPO_ROOT" && ./scripts/diag-sandbox.sh) || log_warn "diag-sandbox.sh reported issues (see above)."
    fi
  else
    log_warn "Sandbox git remote still missing after post-start."
    log_warn "One-time maintainer bootstrap (if sandbox repo does not exist yet):"
    log_warn "  export BOOTSTRAP_GH_TOKEN=\"<owner-level bootstrap token>\""
    log_warn "  ./scripts/sandbox-bootstrap.sh"
    log_warn "Repository creation needs owner-level access; see the guide before using the broader classic fallback."
    log_warn "See docs/guides/sandbox-verification.md § One-time setup."
  fi
else
  log_warn "Not a git checkout; skipping sandbox remote setup."
fi

log_info "Codespace post-start complete."
exit 0
