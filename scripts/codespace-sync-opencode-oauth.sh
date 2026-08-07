#!/usr/bin/env bash
# Synchronize access-only OpenCode OAuth during Codespace lifecycle events.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CODESPACE_OAUTH_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=scripts/lib/ensure-gh-pat-auth.sh
source "$SCRIPT_DIR/lib/ensure-gh-pat-auth.sh"

if [[ "${CODESPACES:-}" != "true" ]]; then
  log_info "Not a Codespace; skipping automatic OpenCode OAuth synchronization."
  exit 0
fi

ensure_gh_pat_auth
if [[ "${ENSURE_GH_PAT_AUTH_UPGRADED:-false}" == "true" ]]; then
  apply_gh_pat_session_exports || true
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
  exit 0
fi

if (cd "$REPO_ROOT" && "$SCRIPT_DIR/sync-opencode-oauth-secret.sh" --apply --if-changed); then
  log_info "OpenCode OAuth synchronization check completed."
else
  log_warn "OpenCode OAuth access synchronization failed; the next Codespace attach will retry."
fi

exit 0
