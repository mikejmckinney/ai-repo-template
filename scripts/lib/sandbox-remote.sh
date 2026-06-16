#!/usr/bin/env bash
# scripts/lib/sandbox-remote.sh — resolve sandbox slug/URL and ensure git remote.
#
# Defaults match scripts/sandbox-bootstrap.sh:
#   SANDBOX_REPO_NAME  override full "owner/repo-sandbox" slug (optional)
#   SANDBOX_REMOTE     local remote name (default: sandbox)
#
# Requires logging.sh when calling sandbox_ensure_git_remote (log_* helpers).

# shellcheck disable=SC2034
SANDBOX_REPO=""
SANDBOX_REMOTE=""
SANDBOX_URL=""
UPSTREAM_OWNER=""
UPSTREAM_NAME=""

sandbox_resolve_targets() {
  local repo_root="$1"
  local upstream_url

  SANDBOX_REPO=""
  SANDBOX_REMOTE=""
  SANDBOX_URL=""
  UPSTREAM_OWNER=""
  UPSTREAM_NAME=""

  if ! git -C "$repo_root" rev-parse --is-inside-work-tree &>/dev/null; then
    return 1
  fi
  if ! upstream_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)"; then
    return 1
  fi

  UPSTREAM_NAME="$(basename "$upstream_url" .git)"
  UPSTREAM_NAME="${UPSTREAM_NAME%.git}"
  if ! UPSTREAM_OWNER="$(cd "$repo_root" && gh repo view --json owner -q .owner.login 2>/dev/null)"; then
    return 2
  fi

  SANDBOX_REPO="${SANDBOX_REPO_NAME:-${UPSTREAM_OWNER}/${UPSTREAM_NAME}-sandbox}"
  SANDBOX_REMOTE="${SANDBOX_REMOTE:-sandbox}"
  SANDBOX_URL="https://github.com/${SANDBOX_REPO}.git"
  return 0
}

sandbox_ensure_git_remote() {
  local repo_root="$1"
  local resolve_rc current_url

  if ! sandbox_resolve_targets "$repo_root"; then
    resolve_rc=$?
    if [[ "$resolve_rc" -eq 2 ]]; then
      log_warn "Could not resolve upstream owner via gh; skipping sandbox remote add."
    else
      log_warn "No git 'origin' remote; skipping sandbox remote add."
    fi
    return 1
  fi

  if git -C "$repo_root" remote get-url "$SANDBOX_REMOTE" &>/dev/null; then
    current_url="$(git -C "$repo_root" remote get-url "$SANDBOX_REMOTE")"
    if [[ "$current_url" == "$SANDBOX_URL" ]]; then
      log_info "Sandbox git remote '$SANDBOX_REMOTE' already configured ($SANDBOX_URL)."
      return 0
    fi
    log_warn "Sandbox git remote '$SANDBOX_REMOTE' points elsewhere ($current_url); leaving untouched."
    log_warn "Run: git -C \"$repo_root\" remote set-url $SANDBOX_REMOTE $SANDBOX_URL"
    return 0
  fi

  if git -C "$repo_root" remote add "$SANDBOX_REMOTE" "$SANDBOX_URL"; then
    log_info "Added sandbox git remote '$SANDBOX_REMOTE' → $SANDBOX_URL"
    return 0
  fi

  log_warn "Failed to add sandbox git remote '$SANDBOX_REMOTE' → $SANDBOX_URL"
  return 1
}
