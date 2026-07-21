#!/usr/bin/env bash
# scripts/workflows/lib/sandbox-sync-fix-branch.sh — push fix branch to sandbox + open PR.
#
# Usage:
#   sandbox_sync_fix_branch <repo_root> <sandbox_branch> <title> <body_file>
#
# Skips (exit 0) when:
#   - FIX_JOB_SANDBOX_VERIFY is not true
#   - GITHUB_REPOSITORY ends with -sandbox
#   - SKIP_SANDBOX_FIX_VERIFY=true
#
# Requires SANDBOX_BOOTSTRAP_TOKEN (or GH_TOKEN) with repo+workflow on sandbox.

set -euo pipefail

sandbox_push_with_askpass() (
  local repo_root="$1"
  local remote="$2"
  local sandbox_branch="$3"
  local askpass_file
  askpass_file="$(mktemp "${TMPDIR:-/tmp}/sandbox-git-askpass.XXXXXX")"
  cleanup_askpass() {
    local status=$?
    trap - EXIT HUP INT TERM
    rm -f -- "$askpass_file"
    exit "$status"
  }
  trap cleanup_askpass EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  chmod 700 "$askpass_file"
  cat >"$askpass_file" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  Username*) printf '%s\n' x-access-token ;;
  Password*) printf '%s\n' "${SANDBOX_BOOTSTRAP_TOKEN:?}" ;;
  *) exit 1 ;;
esac
EOF
  local push_status
  set +e
  GIT_ASKPASS="$askpass_file" GIT_TERMINAL_PROMPT=0 \
    git -C "$repo_root" push -f "$remote" "HEAD:${sandbox_branch}"
  push_status=$?
  set -e
  exit "$push_status"
)

sandbox_sync_should_skip() {
  if [[ "${SKIP_SANDBOX_FIX_VERIFY:-}" == "true" ]]; then
    echo "::notice::sandbox-sync skipped (SKIP_SANDBOX_FIX_VERIFY=true)" >&2
    return 0
  fi
  local repo="${GITHUB_REPOSITORY:-}"
  if [[ "$repo" == *-sandbox ]]; then
    echo "::notice::sandbox-sync skipped (running on sandbox repo)" >&2
    return 0
  fi
  if [[ "${FIX_JOB_SANDBOX_VERIFY:-false}" != "true" ]]; then
    echo "::notice::sandbox-sync skipped (FIX_JOB_SANDBOX_VERIFY not true)" >&2
    return 0
  fi
  return 1
}

sandbox_sync_fix_branch() {
  local repo_root="$1"
  local sandbox_branch="$2"
  local title="$3"
  local body_file="$4"
  local GH_TOKEN="${GH_TOKEN:-}"
  local SANDBOX_BOOTSTRAP_TOKEN="${SANDBOX_BOOTSTRAP_TOKEN:-}"

  if sandbox_sync_should_skip; then
    return 0
  fi

  local script_dir lib_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  lib_dir="$(cd "$script_dir/../.." && pwd)/lib"
  repo_root="$(cd "$repo_root" && pwd)"

  # shellcheck source=../../lib/logging.sh
  source "$lib_dir/logging.sh"
  # shellcheck source=../../lib/sandbox-remote.sh
  source "$lib_dir/sandbox-remote.sh"

  if [[ -n "${SANDBOX_BOOTSTRAP_TOKEN:-}" ]]; then
    export GH_TOKEN="$SANDBOX_BOOTSTRAP_TOKEN"
  elif [[ -z "${GH_TOKEN:-}" ]]; then
    echo "::warning::sandbox-sync: SANDBOX_BOOTSTRAP_TOKEN unset; using existing gh auth" >&2
  fi

  if [[ -x "$repo_root/scripts/diag-sandbox.sh" ]]; then
    (cd "$repo_root" && ./scripts/diag-sandbox.sh) >&2 || {
      echo "::warning::diag-sandbox.sh reported issues; continuing sandbox push"
    }
  fi

  sandbox_resolve_targets "$repo_root" || {
    echo "::error::sandbox-sync: could not resolve sandbox targets" >&2
    return 1
  }
  local configured_url
  if configured_url="$(git -C "$repo_root" remote get-url "${SANDBOX_REMOTE:-sandbox}" 2>/dev/null)" \
    && [[ "$configured_url" =~ ^https?://[^/@]+@ ]]; then
    if ! git -C "$repo_root" remote set-url "${SANDBOX_REMOTE:-sandbox}" "$SANDBOX_URL"; then
      echo "::error::sandbox-sync: could not remove credentials from sandbox remote" >&2
      return 1
    fi
  fi
  sandbox_ensure_git_remote "$repo_root" >&2 || true

  local remote="${SANDBOX_REMOTE:-sandbox}"
  if ! git -C "$repo_root" remote get-url "$remote" &>/dev/null; then
    echo "::error::sandbox-sync: git remote '${remote}' not configured" >&2
    return 1
  fi

  echo "::notice::sandbox-sync pushing HEAD -> ${remote}/${sandbox_branch}" >&2
  if [[ -n "${SANDBOX_BOOTSTRAP_TOKEN:-}" ]]; then
    export SANDBOX_BOOTSTRAP_TOKEN
    if sandbox_push_with_askpass "$repo_root" "$remote" "$sandbox_branch"; then
      :
    else
      return $?
    fi
  else
    git -C "$repo_root" push -f "$remote" "HEAD:${sandbox_branch}"
  fi

  local existing_pr
  existing_pr="$(gh pr list --repo "$SANDBOX_REPO" --head "$sandbox_branch" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"

  local pr_url
  if [[ -n "$existing_pr" ]]; then
    gh pr edit "$existing_pr" --repo "$SANDBOX_REPO" --title "$title" --body-file "$body_file" >/dev/null
    pr_url="$(gh pr view "$existing_pr" --repo "$SANDBOX_REPO" --json url --jq .url)"
    echo "::notice::sandbox-sync updated sandbox PR #${existing_pr}" >&2
  else
    pr_url="$(gh pr create --repo "$SANDBOX_REPO" \
      --title "$title" \
      --body-file "$body_file" \
      --base main \
      --head "$sandbox_branch")"
    echo "::notice::sandbox-sync created sandbox PR ${pr_url}" >&2
  fi

  printf '%s\n' "$pr_url"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  [[ $# -ge 4 ]] || {
    echo "Usage: sandbox-sync-fix-branch.sh <repo_root> <sandbox_branch> <title> <body_file>" >&2
    exit 2
  }
  sandbox_sync_fix_branch "$@"
fi
