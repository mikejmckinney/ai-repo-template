#!/usr/bin/env bash
# .github/scripts/upsert-pr-comment.sh — idempotent sticky PR issue comment.
# Usage: upsert-pr-comment.sh <pr-number> <marker> <body-file>
set -euo pipefail

usage() {
  echo "Usage: upsert-pr-comment.sh <pr-number> <marker> <body-file>" >&2
  exit 2
}

[[ $# -eq 3 ]] || usage

PR="$1"
MARKER="$2"
BODY_FILE="$3"

if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
  GH_TOKEN="$GITHUB_TOKEN"
  export GH_TOKEN
fi

[[ -n "${GH_TOKEN:-}" ]] || {
  echo "upsert-pr-comment.sh: GH_TOKEN or GITHUB_TOKEN required" >&2
  exit 1
}

REPO="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

[[ -f "$BODY_FILE" ]] || {
  echo "upsert-pr-comment.sh: body file missing: $BODY_FILE" >&2
  exit 1
}

comment_id=$(
  gh api "repos/${REPO}/issues/${PR}/comments" --paginate \
    --jq ".[] | select(.body | contains(\"${MARKER}\")) | .id" | head -1
)

if [[ -n "$comment_id" ]]; then
  # -F (typed field) reads @file; -f (raw field) posts the literal "@/path" string.
  gh api --method PATCH "repos/${REPO}/issues/comments/${comment_id}" \
    -F body=@"$BODY_FILE" >/dev/null
  echo "Updated issue comment ${comment_id} on PR #${PR}"
else
  gh api --method POST "repos/${REPO}/issues/${PR}/comments" \
    -F body=@"$BODY_FILE" >/dev/null
  echo "Created issue comment on PR #${PR}"
fi
