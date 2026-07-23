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

owner="${REPO%%/*}"
name="${REPO#*/}"
# shellcheck disable=SC2016 # GraphQL variables are expanded by GitHub, not Bash.
query='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){closingIssuesReferences(first:100){nodes{number}}}}}'
native_link_exists() {
  local linked
  linked="$(gh api graphql -f query="$query" -F owner="$owner" -F name="$name" \
    -F number="$PR_NUM" --jq ".data.repository.pullRequest.closingIssuesReferences.nodes | any(.number == ${ISSUE_NUM})" \
    2>/dev/null || true)"
  [[ "$linked" == true ]]
}

if native_link_exists; then
  echo "PR #${PR_NUM} has a native Development-graph link to issue #${ISSUE_NUM}"
  exit 0
fi

link_line="Fixes #${ISSUE_NUM}"
updated="$body"
if ! grep -Eq "(^|[[:space:]])(Fixes|Closes|Resolves)[[:space:]]+#${ISSUE_NUM}([[:space:][:punct:]]|$)" <<<"$body"; then
  updated="$(
    python3 - "$body" "$link_line" <<'PY'
import sys

body, link_line = sys.argv[1:3]
needle = "## Linked issues"
if needle in body:
    head, tail = body.split(needle, 1)
    print(head.rstrip() + "\n\n" + needle + "\n\n" + link_line + tail)
else:
    print(body.rstrip() + "\n\n" + needle + "\n\n" + link_line + "\n")
PY
  )"
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
printf '%s' "$updated" >"$WORKDIR/body.md"
gh pr edit "$PR_NUM" -R "$REPO" --body-file "$WORKDIR/body.md"

attempts="${LINK_VERIFY_ATTEMPTS:-3}"
delay_seconds="${LINK_VERIFY_DELAY_SECONDS:-2}"
for ((attempt = 1; attempt <= attempts; attempt++)); do
  if native_link_exists; then
    echo "PR #${PR_NUM} has a native Development-graph link to issue #${ISSUE_NUM}"
    exit 0
  fi
  if [[ "$attempt" -lt "$attempts" && "$delay_seconds" != 0 ]]; then
    sleep "$delay_seconds"
  fi
done

echo "::error::GitHub did not register issue #${ISSUE_NUM} for https://github.com/${REPO}/pull/${PR_NUM}; link it manually and rerun the fix job" >&2
exit 1
