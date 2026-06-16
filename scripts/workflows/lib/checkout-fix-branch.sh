#!/usr/bin/env bash
# Prepare the fix-job working branch: continue an existing remote branch or start fresh from main.
#
# Usage (source, then call):
#   source scripts/workflows/lib/checkout-fix-branch.sh
#   checkout_fix_branch <repo> <branch>
#
# Sets CHECKOUT_FIX_OPEN_PR_NUM to the open draft PR number when one exists, else empty.

_continue_fix_branch() {
  local branch="$1" open_pr="${2:-}" notice="$3"

  CHECKOUT_FIX_OPEN_PR_NUM="$open_pr"
  export CHECKOUT_FIX_OPEN_PR_NUM
  echo "::notice::${notice}"
  git checkout -B "$branch" "origin/${branch}"
  if ! git merge origin/main --no-edit -m "merge: sync ${branch} with main"; then
    echo "::error::Failed to merge origin/main into ${branch}; resolve conflicts on the fix branch before re-running the fix job" >&2
    exit 1
  fi
}

checkout_fix_branch() {
  local repo="$1" branch="$2"

  [[ -n "$repo" && -n "$branch" ]] || {
    echo "::error::checkout_fix_branch requires <repo> <branch>" >&2
    exit 2
  }

  git fetch origin main "$branch" 2>/dev/null || git fetch origin main

  local open_pr="" closed_pr="" remote_exists=0
  open_pr="$(gh pr list -R "$repo" --head "$branch" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  closed_pr="$(gh pr list -R "$repo" --head "$branch" --state closed --json number --jq '.[0].number // empty' 2>/dev/null || true)"

  if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    remote_exists=1
  fi

  if [[ -n "$open_pr" ]]; then
    _continue_fix_branch "$branch" "$open_pr" "Continuing existing draft PR #${open_pr} on ${branch}"
    return 0
  fi

  if [[ "$remote_exists" -eq 1 ]]; then
    if [[ -n "$closed_pr" ]]; then
      echo "::error::Fix branch ${branch} exists but draft PR #${closed_pr} is closed; delete the branch or reopen the PR before re-running the fix job" >&2
      exit 1
    fi
    _continue_fix_branch "$branch" "" "Continuing existing fix branch ${branch} (no open draft PR yet)"
    return 0
  fi

  CHECKOUT_FIX_OPEN_PR_NUM=""
  export CHECKOUT_FIX_OPEN_PR_NUM
  git checkout -B "$branch" origin/main
}
