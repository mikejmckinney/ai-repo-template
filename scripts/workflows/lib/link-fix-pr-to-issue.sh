#!/usr/bin/env bash
# Ensure a fix PR has a GitHub Development-graph link to its umbrella issue.
# Usage: link-fix-pr-to-issue.sh <repo> <pr-number> <issue-number>
set -euo pipefail

usage() {
  echo "Usage: link-fix-pr-to-issue.sh <repo> <pr-number> <issue-number>" >&2
  exit 2
}

REPO="${1:-}"
PR_NUM="${2:-}"
ISSUE_NUM="${3:-}"
[[ -n "$REPO" && -n "$PR_NUM" && -n "$ISSUE_NUM" ]] || usage
[[ "$ISSUE_NUM" =~ ^[0-9]+$ ]] || {
  echo "::error::issue-number must be a positive integer: ${ISSUE_NUM}" >&2
  exit 1
}
[[ "$PR_NUM" =~ ^[0-9]+$ ]] || {
  echo "::error::pr-number must be a positive integer: ${PR_NUM}" >&2
  exit 1
}

body="$(gh pr view "$PR_NUM" -R "$REPO" --json body --jq .body 2>/dev/null || true)"
[[ -n "$body" ]] || {
  echo "::error::Could not read PR #${PR_NUM} body" >&2
  exit 1
}

if grep -Eq "(^|[[:space:]])(Fixes|Closes|Resolves)[[:space:]]+#${ISSUE_NUM}([[:space:][:punct:]]|$)" <<<"$body"; then
  echo "PR #${PR_NUM} already links issue #${ISSUE_NUM} via closing keyword"
  exit 0
fi

link_line="Fixes #${ISSUE_NUM}"
updated=""
if grep -Fq "## Linked issues" <<<"$body"; then
  updated="$(
    python3 - "$body" "$link_line" <<'PY'
import sys

body, link_line = sys.argv[1:3]
needle = "## Linked issues"
if link_line in body:
    print(body)
elif needle in body:
    head, tail = body.split(needle, 1)
    print(head.rstrip() + "\n\n" + needle + "\n\n" + link_line + tail)
else:
    print(body.rstrip() + "\n\n" + needle + "\n\n" + link_line + "\n")
PY
  )"
else
  updated="${body}"$'\n\n'"## Linked issues"$'\n\n'"${link_line}"$'\n'
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
printf '%s' "$updated" >"$WORKDIR/body.md"
gh pr edit "$PR_NUM" -R "$REPO" --body-file "$WORKDIR/body.md"
echo "Linked PR #${PR_NUM} to issue #${ISSUE_NUM} (Fixes keyword)"
