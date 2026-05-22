#!/usr/bin/env bash
# pr-resolve-all-poll.sh — pre-#321 settle-window poller for pr-resolve-all.
#
# Usage:
#   scripts/pr-resolve-all-poll.sh <PR_NUMBER>
#
# Environment variable defaults:
#   INTERVAL=20      poll cadence in seconds
#   QUIET_WINDOW=360 quiet-window fallback in seconds
#   MAX_WAIT=900     hard timeout in seconds
#   ALLOWLIST_FILE=scripts/lib/bot-allowlist.txt
#
# Exit codes / final RESULT values:
#   0  RESULT=CONVERGED      all participating allow-listed bots are terminal
#                            on the current head SHA and no unresolved
#                            allow-listed bot-rooted review threads remain
#   0  RESULT=QUIET_ELAPSED  quiet window elapsed since the latest actionable
#                            PR event; proceed to the next fetch / round step
#   2  RESULT=TIMEOUT        hard-cap timeout reached
#   3  RESULT=SHA_CHANGED    PR head SHA changed during polling
#   4  RESULT=API_ERROR      gh / GraphQL / auth / jq / allow-list failure
#
# Pre-#321 semantics:
#   - State is memory-only; every fresh run rebuilds from GitHub APIs.
#   - "Participating" bots are allow-listed bots that have reviewed or
#     commented on this PR.
#   - "Terminal on current head" is conservative in v0: for a participating
#     bot, it submitted a non-pending review against the current head SHA and
#     has zero unresolved allow-listed bot-rooted threads of its own.
#     Comment-only bot activity still contributes to the quiet-window fallback,
#     but it does not prove current-head convergence on its own because commit
#     timestamps are not a safe proxy for push order after rebases/force-pushes.
#   - The quiet-window fallback is measured from the latest PR activity
#     timestamp (reviews, PR comments, review-thread comments), falling back
#     to the head commit timestamp only when no newer PR activity exists.
#   - This helper does not yet parse #321 Index / Resolution Report markers.

set -euo pipefail

umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INTERVAL="${INTERVAL:-20}"
QUIET_WINDOW="${QUIET_WINDOW:-360}"
MAX_WAIT="${MAX_WAIT:-900}"
ALLOWLIST_FILE="${ALLOWLIST_FILE:-$REPO_ROOT/scripts/lib/bot-allowlist.txt}"

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <PR_NUMBER>\n' "$0" >&2
  exit 1
fi

PR_NUMBER="$1"
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  printf 'Error: PR_NUMBER must be a positive integer\n' >&2
  exit 1
fi

for n in "$INTERVAL" "$QUIET_WINDOW" "$MAX_WAIT"; do
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    printf 'Error: INTERVAL, QUIET_WINDOW, and MAX_WAIT must be non-negative integers\n' >&2
    exit 1
  fi
done

QUERY_HEAD='
query($owner:String!, $name:String!, $number:Int!) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      headRefOid
      commits(last: 1) {
        nodes {
          commit {
            oid
            committedDate
          }
        }
      }
    }
  }
}
'

QUERY_REVIEWS='
query($owner:String!, $name:String!, $number:Int!, $after:String) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      reviews(first: 100, after: $after) {
        nodes {
          author { login }
          submittedAt
          state
          commit { oid }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'

QUERY_COMMENTS='
query($owner:String!, $name:String!, $number:Int!, $after:String) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      comments(first: 100, after: $after) {
        nodes {
          author { login }
          createdAt
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'

QUERY_THREADS='
query($owner:String!, $name:String!, $number:Int!, $after:String) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      reviewThreads(first: 100, after: $after) {
        nodes {
          id
          isResolved
          comments(first: 100) {
            nodes {
              author { login }
              createdAt
            }
            pageInfo { hasNextPage endCursor }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'

QUERY_THREAD_COMMENTS='
query($threadId:ID!, $after:String) {
  node(id:$threadId) {
    ... on PullRequestReviewThread {
      comments(first: 100, after: $after) {
        nodes {
          author { login }
          createdAt
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
'

emit_result() {
  local code="$1" result="$2" head="${3:-}" extra="${4:-}"
  if [[ -n "$extra" ]]; then
    printf 'RESULT=%s%s%s\n' "$result" "${head:+ HEAD=$head}" " $extra"
  else
    printf 'RESULT=%s%s\n' "$result" "${head:+ HEAD=$head}"
  fi
  exit "$code"
}

require_cmd() {
  local cmd="$1"
  local upper_cmd
  if ! command -v "$cmd" >/dev/null 2>&1; then
    upper_cmd=$(printf '%s' "$cmd" | tr '[:lower:]' '[:upper:]')
    emit_result 4 API_ERROR "" "ERROR=MISSING_${upper_cmd}"
  fi
}

require_cmd gh
require_cmd jq

REPO="${GH_REPO:-}"
REPO_HOST="${GH_HOST:-github.com}"
if [[ "$REPO" == */*/* ]]; then
  REPO_HOST="${REPO%%/*}"
  REPO="${REPO#*/}"
fi

export GH_HOST="$REPO_HOST"

if ! gh auth token -h "$REPO_HOST" >/dev/null 2>&1; then
  emit_result 4 API_ERROR "" "ERROR=GH_AUTH"
fi

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  emit_result 4 API_ERROR "" "ERROR=MISSING_ALLOWLIST"
fi

if ! allowlist_json=$(jq -Rn -f "$REPO_ROOT/scripts/lib/jq/bot-allowlist-normalize.jq" <"$ALLOWLIST_FILE"); then
  emit_result 4 API_ERROR "" "ERROR=ALLOWLIST_PARSE_FAIL"
fi
if [[ "$(jq 'length' <<<"$allowlist_json")" -eq 0 ]]; then
  emit_result 4 API_ERROR "" "ERROR=EMPTY_ALLOWLIST"
fi

if [[ -z "$REPO" ]]; then
  if ! REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner'); then
    emit_result 4 API_ERROR "" "ERROR=REPO_VIEW"
  fi
fi

if [[ "$REPO" == */*/* ]]; then
  REPO="${REPO#*/}"
fi
OWNER="${REPO%/*}"
NAME="${REPO#*/}"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pr-resolve-all-poll.${USER:-user}.XXXXXX")
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

head_file="$TMP_DIR/head.json"
post_head_file="$TMP_DIR/post-head.json"
reviews_file="$TMP_DIR/reviews.json"
comments_file="$TMP_DIR/comments.json"
threads_file="$TMP_DIR/threads.json"
state_file="$TMP_DIR/state.json"
SNAPSHOT_ERROR="SNAPSHOT"

gh_graphql() {
  local out_file="$1"
  shift
  if ! gh api graphql "$@" >"$out_file"; then
    return 1
  fi
}

fetch_head() {
  local out_file="$1"
  gh_graphql "$out_file" \
    -F owner="$OWNER" \
    -F name="$NAME" \
    -F number="$PR_NUMBER" \
    -f query="$QUERY_HEAD" || {
    SNAPSHOT_ERROR="GRAPHQL_HEAD"
    return 1
  }
}

fetch_paginated_nodes() {
  local kind="$1" out_file="$2"
  local cursor=""
  printf '[]\n' >"$out_file"

  while :; do
    local page_file page_path nodes has_next end_cursor
    page_file="$TMP_DIR/${kind}-page.$RANDOM.json"
    case "$kind" in
      reviews)
        if [[ -n "$cursor" ]]; then
          gh_graphql "$page_file" -F owner="$OWNER" -F name="$NAME" -F number="$PR_NUMBER" -F after="$cursor" -f query="$QUERY_REVIEWS" || {
            SNAPSHOT_ERROR="GRAPHQL_REVIEWS"
            return 1
          }
        else
          gh_graphql "$page_file" -F owner="$OWNER" -F name="$NAME" -F number="$PR_NUMBER" -f query="$QUERY_REVIEWS" || {
            SNAPSHOT_ERROR="GRAPHQL_REVIEWS"
            return 1
          }
        fi
        page_path='.data.repository.pullRequest.reviews'
        ;;
      comments)
        if [[ -n "$cursor" ]]; then
          gh_graphql "$page_file" -F owner="$OWNER" -F name="$NAME" -F number="$PR_NUMBER" -F after="$cursor" -f query="$QUERY_COMMENTS" || {
            SNAPSHOT_ERROR="GRAPHQL_COMMENTS"
            return 1
          }
        else
          gh_graphql "$page_file" -F owner="$OWNER" -F name="$NAME" -F number="$PR_NUMBER" -f query="$QUERY_COMMENTS" || {
            SNAPSHOT_ERROR="GRAPHQL_COMMENTS"
            return 1
          }
        fi
        page_path='.data.repository.pullRequest.comments'
        ;;
      threads)
        if [[ -n "$cursor" ]]; then
          gh_graphql "$page_file" -F owner="$OWNER" -F name="$NAME" -F number="$PR_NUMBER" -F after="$cursor" -f query="$QUERY_THREADS" || {
            SNAPSHOT_ERROR="GRAPHQL_THREADS"
            return 1
          }
        else
          gh_graphql "$page_file" -F owner="$OWNER" -F name="$NAME" -F number="$PR_NUMBER" -f query="$QUERY_THREADS" || {
            SNAPSHOT_ERROR="GRAPHQL_THREADS"
            return 1
          }
        fi
        page_path='.data.repository.pullRequest.reviewThreads'
        ;;
      *)
        return 1
        ;;
    esac

    nodes=$(jq "${page_path}.nodes // []" "$page_file")
    jq -c --argjson nodes "$nodes" '. + $nodes' "$out_file" >"$out_file.tmp"
    mv "$out_file.tmp" "$out_file"

    has_next=$(jq -r "${page_path}.pageInfo.hasNextPage // false" "$page_file")
    if [[ "$has_next" != "true" ]]; then
      break
    fi
    end_cursor=$(jq -r "${page_path}.pageInfo.endCursor // empty" "$page_file")
    if [[ -z "$end_cursor" ]]; then
      break
    fi
    cursor="$end_cursor"
  done
}

expand_thread_comments() {
  local thread_id="$1"
  local cursor
  cursor=$(jq -r --arg id "$thread_id" '.[] | select(.id == $id) | .comments.pageInfo.endCursor // empty' "$threads_file")
  while [[ -n "$cursor" ]]; do
    local page_file comments has_next
    page_file="$TMP_DIR/thread-comments.$RANDOM.json"
    gh_graphql "$page_file" -F threadId="$thread_id" -F after="$cursor" -f query="$QUERY_THREAD_COMMENTS" || {
      SNAPSHOT_ERROR="GRAPHQL_THREAD_COMMENTS"
      return 1
    }
    comments=$(jq '.data.node.comments.nodes // []' "$page_file")
    jq -c --arg id "$thread_id" --argjson comments "$comments" '
      map(
        if .id == $id
        then .comments.nodes += $comments
        else .
        end
      )
    ' "$threads_file" >"$threads_file.tmp"
    mv "$threads_file.tmp" "$threads_file"
    has_next=$(jq -r '.data.node.comments.pageInfo.hasNextPage // false' "$page_file")
    if [[ "$has_next" != "true" ]]; then
      jq -c --arg id "$thread_id" '
        map(
          if .id == $id
          then .comments.pageInfo.hasNextPage = false
          else .
          end
        )
      ' "$threads_file" >"$threads_file.tmp"
      mv "$threads_file.tmp" "$threads_file"
      break
    fi
    cursor=$(jq -r '.data.node.comments.pageInfo.endCursor // empty' "$page_file")
  done
}

build_state() {
  SNAPSHOT_ERROR="SNAPSHOT"
  if ! fetch_head "$head_file"; then
    return 4
  fi

  if ! fetch_paginated_nodes reviews "$reviews_file"; then
    return 4
  fi
  if ! fetch_paginated_nodes comments "$comments_file"; then
    return 4
  fi
  if ! fetch_paginated_nodes threads "$threads_file"; then
    return 4
  fi

  while IFS= read -r thread_id; do
    [[ -n "$thread_id" ]] || continue
    if ! expand_thread_comments "$thread_id"; then
      return 4
    fi
  done < <(jq -r '.[] | select(.comments.pageInfo.hasNextPage == true) | .id' "$threads_file")

  if ! fetch_head "$post_head_file"; then
    return 4
  fi

  local pre_sha post_sha
  pre_sha=$(jq -r '.data.repository.pullRequest.headRefOid // empty' "$head_file")
  post_sha=$(jq -r '.data.repository.pullRequest.headRefOid // empty' "$post_head_file")
  if [[ -z "$pre_sha" || -z "$post_sha" ]]; then
    SNAPSHOT_ERROR="HEAD_MISSING"
    return 4
  fi
  if [[ "$pre_sha" != "$post_sha" ]]; then
    return 3
  fi

  if ! jq -n \
    --argjson allowlist "$allowlist_json" \
    --slurpfile head "$head_file" \
    --slurpfile reviews "$reviews_file" \
    --slurpfile pr_comments "$comments_file" \
    --slurpfile threads "$threads_file" \
    -f "$REPO_ROOT/scripts/lib/jq/pr-poll-state.jq" >"$state_file"; then
    SNAPSHOT_ERROR="STATE_BUILD"
    return 1
  fi
}

start_epoch=$(date +%s)

while :; do
  if build_state; then
    build_state_rc=0
  else
    build_state_rc=$?
  fi
  case "$build_state_rc" in
    0) ;;
    3)
      head_sha=$(jq -r '.data.repository.pullRequest.headRefOid // empty' "$head_file")
      if ! head_changed_to=$(jq -r '.data.repository.pullRequest.headRefOid // empty' "$post_head_file"); then
        emit_result 4 API_ERROR "$head_sha" "ERROR=GRAPHQL_HEAD_POST"
      fi
      emit_result 3 SHA_CHANGED "$head_changed_to"
      ;;
    *)
      emit_result 4 API_ERROR "" "ERROR=${SNAPSHOT_ERROR:-SNAPSHOT}"
      ;;
  esac

  head_sha=$(jq -r '.head // empty' "$state_file")
  latest_actionable=$(jq -r '.latest_actionable // empty' "$state_file")
  latest_actionable_epoch=$(jq -r '.latest_actionable_epoch // empty' "$state_file")
  participating_count=$(jq '.participating_bots | length' "$state_file")
  terminal_count=$(jq '[.bots[] | select(.terminal == true)] | length' "$state_file")
  unresolved_threads=$(jq '.unresolved_threads // 0' "$state_file")
  participating_csv=$(jq -r '.participating_bots | join(",")' "$state_file")
  pending_csv=$(jq -r '[.bots[] | select(.current_head_pending == true) | .login] | join(",")' "$state_file")

  now_epoch=$(date +%s)
  elapsed=$((now_epoch - start_epoch))
  quiet_for=0
  if [[ -n "$latest_actionable" && "$latest_actionable_epoch" == "" ]]; then
    emit_result 4 API_ERROR "$head_sha" "ERROR=TIMESTAMP_PARSE"
  fi
  if [[ -n "$latest_actionable_epoch" && "$latest_actionable_epoch" != "null" ]]; then
    quiet_for=$((now_epoch - latest_actionable_epoch))
  fi

  printf 'HEAD=%s participating=%s terminal=%s unresolved_threads=%s latest_actionable=%s quiet_for=%ss elapsed=%ss' \
    "$head_sha" \
    "${participating_csv:-<none>}" \
    "$terminal_count/$participating_count" \
    "$unresolved_threads" \
    "${latest_actionable:-<none>}" \
    "$quiet_for" \
    "$elapsed" >&2
  if [[ -n "$pending_csv" ]]; then
    printf ' pending=%s' "$pending_csv" >&2
  fi
  printf '\n' >&2

  if [[ "$participating_count" -gt 0 && "$terminal_count" -eq "$participating_count" && "$unresolved_threads" -eq 0 ]]; then
    emit_result 0 CONVERGED "$head_sha" "QUIET_FOR=${quiet_for}s"
  fi

  if [[ -z "$pending_csv" && "$quiet_for" -ge "$QUIET_WINDOW" ]]; then
    emit_result 0 QUIET_ELAPSED "$head_sha" "QUIET_FOR=${quiet_for}s"
  fi

  if [[ "$elapsed" -ge "$MAX_WAIT" ]]; then
    emit_result 2 TIMEOUT "$head_sha" "ELAPSED=${elapsed}s"
  fi

  sleep "$INTERVAL"
done
