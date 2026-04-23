#!/usr/bin/env bash
# Auto-rebase-on-merge support library (#116).
#
# Sourced by .github/workflows/auto-rebase-on-merge.yml AND by
# scripts/test-auto-rebase-overlapping.sh. Exposes pure-bash functions
# that can be unit-tested without `gh` or a live git repo.
#
# Functions
# ---------
#   should_rebase_pr <pr_number> <merged_pr_number>
#       Decide what to do with `<pr_number>` after `<merged_pr_number>`
#       merged. Reads PR metadata (labels, fork-flag, draft-flag, files,
#       unresolved-thread count) and reuses classify_overlap from
#       multi-dispatch-safety.sh.
#       Emits exactly one line on stdout:
#         attempt-rebase           — soft overlap, opted in, all checks pass
#         comment-only             — hard overlap, opted in, all checks pass
#         skip:<reason>            — anything else
#       Reasons: same-pr | fork | draft | not-opted-in | opted-out
#                | unresolved-threads | none-overlap
#
#   attempt_rebase <branch> <expected_sha> <work_dir>
#       Run `git rebase origin/main` inside <work_dir> on a checkout of
#       <branch>. Pure git, no gh.
#       Emits:
#         clean                    — rebase succeeded; new HEAD is on top
#         conflict:path1,path2,... — rebase aborted; comma-separated
#                                    list of conflicting paths
#       This function performs `git rebase --abort` cleanup on conflict.
#       The caller is responsible only for the subsequent
#       `git push --force-with-lease=<branch>:<expected_sha>` on success.
#
#   format_success_comment <merged_pr> <new_sha>
#       Print the canonical success-comment body to stdout, with the
#       <!-- auto-rebase-success --> marker for upsert.
#
#   format_conflict_comment <merged_pr> <conflict_paths>
#       Print the canonical conflict-comment body for soft-overlap
#       rebase failures, with the <!-- auto-rebase-conflict --> marker.
#       <conflict_paths> is comma-separated (matches attempt_rebase).
#
#   format_overlap_warning_comment <merged_pr> <overlapping_paths>
#       Print the canonical advisory-comment body for hard-overlap
#       (no rebase attempted), with the <!-- auto-rebase-overlap -->
#       marker. <overlapping_paths> is newline-separated.
#
# Test mode
# ---------
# When `AUTO_REBASE_TEST_MODE=1` is set, the GitHub-touching parts read
# from fixture files instead of `gh`:
#   FIXTURE_DIR/<N>.labels        — one label per line
#   FIXTURE_DIR/<N>.is_fork       — `true` or `false`
#   FIXTURE_DIR/<N>.is_draft      — `true` or `false`
#   FIXTURE_DIR/<N>.files         — one path per line (PR's changed files)
#   FIXTURE_DIR/<N>.unresolved    — integer count of unresolved threads
# Tests set AUTO_REBASE_TEST_MODE=1 + FIXTURE_DIR=... before sourcing.
#
# See issue #116 and ADR-010.

set -euo pipefail

# ── Resolve repo paths regardless of CWD ──
_ARO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ARO_REPO_ROOT="$(cd "$_ARO_LIB_DIR/.." && pwd)"

# Source the shared classify_overlap implementation. The multi-dispatch
# library uses `set -euo pipefail` and exposes classify_overlap. We
# explicitly do NOT want its MULTI_DISPATCH_TEST_MODE to leak in here,
# but classify_overlap itself only reads two file arguments + the
# ownership map, so it's safe in either mode.
# shellcheck disable=SC1091
source "$_ARO_REPO_ROOT/scripts/multi-dispatch-safety.sh"

# ── Internal helpers ──

_aro_pr_labels() {
  local n="$1"
  if [[ "${AUTO_REBASE_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.labels" 2>/dev/null || true
  else
    set -o pipefail
    gh pr view "$n" --json labels --jq '.labels[].name' 2>/dev/null || true
  fi
}

_aro_pr_is_fork() {
  local n="$1"
  if [[ "${AUTO_REBASE_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.is_fork" 2>/dev/null || echo "false"
  else
    set -o pipefail
    gh pr view "$n" --json isCrossRepository --jq '.isCrossRepository' 2>/dev/null || echo "false"
  fi
}

_aro_pr_is_draft() {
  local n="$1"
  if [[ "${AUTO_REBASE_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.is_draft" 2>/dev/null || echo "false"
  else
    set -o pipefail
    gh pr view "$n" --json isDraft --jq '.isDraft' 2>/dev/null || echo "false"
  fi
}

_aro_pr_files() {
  local n="$1"
  if [[ "${AUTO_REBASE_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.files" 2>/dev/null || true
  else
    set -o pipefail
    gh pr view "$n" --json files --jq '.files[].path' 2>/dev/null || true
  fi
}

# Count of unresolved review threads on a PR. The GraphQL query asks for
# the first 100 threads AND `pageInfo.hasNextPage`; if there's a next
# page we fail-closed (return sentinel `999`) so the > 0 gate trips and
# the PR is skipped — better to skip a rebase we could have done than
# to force-push to a PR with hidden unresolved review threads (Copilot
# review #JWJ on PR #143).
#
# Fail-closed: if the API call fails (network, rate-limit, perms), also
# emit sentinel `999`. Better to skip a rebase we could have done than
# to force-push to a PR with unresolved review threads we couldn't see
# (Gemini review medium #3 on PR #143).
_aro_pr_unresolved_threads() {
  local n="$1"
  if [[ "${AUTO_REBASE_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.unresolved" 2>/dev/null || echo "0"
  else
    local repo owner name raw count has_next
    repo="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
    owner="${repo%/*}"
    name="${repo#*/}"
    # shellcheck disable=SC2016  # GraphQL variables (`$owner` etc.) are literal in the query string
    raw=$(set -o pipefail; gh api graphql -f query='
      query($owner: String!, $name: String!, $pr: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100) {
              pageInfo { hasNextPage }
              nodes { isResolved }
            }
          }
        }
      }' -F owner="$owner" -F name="$name" -F pr="$n" 2>/dev/null) \
      || raw=""
    if [[ -z "$raw" ]]; then
      echo "999"; return 0
    fi
    has_next=$(printf '%s' "$raw" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' 2>/dev/null)
    if [[ "$has_next" == "true" ]]; then
      # Pagination would be needed; fail-closed.
      echo "999"; return 0
    fi
    count=$(printf '%s' "$raw" | jq '[.data.repository.pullRequest.reviewThreads.nodes[]
             | select(.isResolved == false)] | length' 2>/dev/null)
    if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
      echo "999"
    else
      echo "$count"
    fi
  fi
}

# ── Public: should_rebase_pr ──
should_rebase_pr() {
  local pr="$1"
  local merged_pr="$2"

  # 0. Self.
  if [[ "$pr" == "$merged_pr" ]]; then
    echo "skip:same-pr"
    return 0
  fi

  # 1. Fork.
  local fork
  fork=$(_aro_pr_is_fork "$pr")
  if [[ "$fork" == "true" ]]; then
    echo "skip:fork"
    return 0
  fi

  # 2. Draft.
  local draft
  draft=$(_aro_pr_is_draft "$pr")
  if [[ "$draft" == "true" ]]; then
    echo "skip:draft"
    return 0
  fi

  # 3. Label gate (opt-in via auto-rebase, opt-out via do-not-rebase).
  local labels
  labels=$(_aro_pr_labels "$pr")
  if printf '%s\n' "$labels" | grep -qFx "do-not-rebase"; then
    echo "skip:opted-out"
    return 0
  fi
  if ! printf '%s\n' "$labels" | grep -qFx "auto-rebase"; then
    echo "skip:not-opted-in"
    return 0
  fi

  # 4. Unresolved threads.
  local unresolved
  unresolved=$(_aro_pr_unresolved_threads "$pr")
  if [[ "${unresolved:-0}" -gt 0 ]]; then
    echo "skip:unresolved-threads"
    return 0
  fi

  # 5. Overlap classification.
  #
  # Use explicit cleanup rather than `trap ... RETURN` because this
  # library is sourced by callers and a RETURN trap would leak into
  # the caller's shell and fire on every subsequent function return
  # (Copilot review #JWY on PR #143; same lesson as multi-dispatch-
  # safety.sh::select_dispatchable).
  local work
  work=$(mktemp -d)
  _aro_pr_files "$pr"        | sort -u > "$work/a"
  _aro_pr_files "$merged_pr" | sort -u > "$work/b"

  local overlap
  overlap=$(classify_overlap "$work/a" "$work/b")
  rm -rf "$work"
  case "$overlap" in
    soft) echo "attempt-rebase" ;;
    hard) echo "comment-only" ;;
    *)    echo "skip:none-overlap" ;;
  esac
}

# ── Public: attempt_rebase ──
#
# Caller has already cd'd or passes work_dir explicitly. This function
# does NOT push; the caller does the force-push-with-lease using the
# expected_sha that was captured BEFORE the rebase.
attempt_rebase() {
  local branch="$1"
  local expected_sha="$2"  # informational: caller uses for --force-with-lease
  local work_dir="$3"

  # Accept both regular checkouts (`.git` is a directory) and `git
  # worktree add` checkouts (`.git` is a file pointing at the parent
  # repo's worktrees/ entry). The workflow always uses `git worktree`
  # so directory-only check would fail every real-world invocation
  # (Codex P1, PR #143).
  if ! git -C "$work_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "conflict:not-a-git-repo"
    return 0
  fi

  (
    set +e
    cd "$work_dir" || exit 1
    git checkout -q "$branch" 2>/dev/null || {
      echo "conflict:checkout-failed"
      exit 0
    }
    # Ensure the working tree is clean.
    if ! git diff --quiet || ! git diff --cached --quiet; then
      echo "conflict:dirty-worktree"
      exit 0
    fi
    # Write the rebase log to a unique tempfile (not under work_dir, so
    # it doesn't show up as untracked in `git status`; not /tmp/foo.log
    # so concurrent runs don't collide — Gemini #4 + Codex P1 followup).
    local log
    log=$(mktemp -t aro-rebase.XXXXXX.log)
    if git rebase origin/main >"$log" 2>&1; then
      rm -f "$log"
      echo "clean"
      exit 0
    fi
    # Conflicts: collect the list, then abort.
    local conflicts
    conflicts=$(git diff --name-only --diff-filter=U 2>/dev/null | paste -sd, -)
    git rebase --abort >/dev/null 2>&1 || true
    rm -f "$log"
    if [[ -z "$conflicts" ]]; then
      conflicts="unknown"
    fi
    echo "conflict:$conflicts"
  )
  # Suppress expected_sha-unused warning while keeping it in the public
  # signature so the workflow caller documents the intended capture.
  : "$expected_sha"
}

# ── Public: format_success_comment ──
format_success_comment() {
  local merged_pr="$1"
  local new_sha="$2"
  cat <<EOF
<!-- auto-rebase-success -->
🤖 **Auto-rebased onto \`main\`** after #${merged_pr} merged.

- New HEAD: \`${new_sha}\`
- Pushed with \`--force-with-lease\`.

If CI fails after this rebase, the conflict is semantic (not textual) — please review the changes from #${merged_pr}.

_To opt out, add the \`do-not-rebase\` label to this PR._
EOF
}

# ── Public: format_conflict_comment ──
format_conflict_comment() {
  local merged_pr="$1"
  local conflict_paths="$2"  # comma-separated
  local files_list
  files_list=$(printf '%s' "$conflict_paths" | tr ',' '\n' | awk 'NF { printf "- `%s`\n", $0 }')
  cat <<EOF
<!-- auto-rebase-conflict -->
⚠️ **Auto-rebase conflict** after #${merged_pr} merged.

I tried to rebase this branch onto \`main\` (because it has soft overlap with the merged PR) and hit conflicts in:

${files_list}

The branch was **not** modified — \`git rebase --abort\` was run cleanly.

**Next steps for the owning agent:**

1. \`git fetch origin && git rebase origin/main\` locally.
2. Resolve the conflicts above.
3. \`git push --force-with-lease\`.

The \`rebase-conflict\` label has been applied so this PR is filterable. Remove it once resolved.
EOF
}

# ── Public: format_overlap_warning_comment ──
format_overlap_warning_comment() {
  local merged_pr="$1"
  local overlapping_paths="$2"  # newline-separated
  local files_list
  files_list=$(printf '%s' "$overlapping_paths" | awk 'NF { printf "- `%s`\n", $0 }')
  cat <<EOF
<!-- auto-rebase-overlap -->
⚠️ **Hard overlap with merged #${merged_pr}** — manual rebase needed.

This PR touches the same file path(s) as #${merged_pr}, which just merged:

${files_list}

I did **not** attempt an auto-rebase — hard overlap almost always conflicts, and the safer path is for the owning agent to handle it explicitly.

**Next steps for the owning agent:**

1. \`git fetch origin && git rebase origin/main\` locally.
2. Resolve the overlapping file(s) above.
3. \`git push --force-with-lease\`.

The \`rebase-conflict\` label has been applied so this PR is filterable. Remove it once resolved.
EOF
}
