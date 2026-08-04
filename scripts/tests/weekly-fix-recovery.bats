#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/bin"
  GH_CALLS_FILE="$TEST_ROOT/gh-calls"
  GH_COMMENTS_FILE="$TEST_ROOT/comments.json"

  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$GH_CALLS_FILE"

if [[ "$1 $2" == "search issues" ]]; then
  printf '204\n'
elif [[ "$1" == "api" && "$2" == "repos/owner/repo/issues/204" ]]; then
  exit 1
elif [[ "$1 $2" == "issue view" && "$*" == *"--json body"* ]]; then
  printf '<!-- weekly-review:2099-W50 -->\n'
elif [[ "$1" == "api" && "$*" == *"/comments?per_page=100"* ]]; then
  if [[ "${GH_COMMENTS_STATUS:-0}" -ne 0 ]]; then
    printf 'HTTP 403: Resource not accessible by integration\n' >&2
    exit "$GH_COMMENTS_STATUS"
  fi
  cat "$GH_COMMENTS_FILE"
else
  printf 'unexpected gh invocation: %s\n' "$*" >&2
  exit 2
fi
EOF
  chmod +x "$TEST_ROOT/bin/gh"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

run_issue_restore() {
  run env PATH="$TEST_ROOT/bin:$PATH" \
    GITHUB_REPOSITORY=owner/repo \
    GH_CALLS_FILE="$GH_CALLS_FILE" \
    GH_COMMENTS_FILE="$GH_COMMENTS_FILE" \
    GH_COMMENTS_STATUS="${GH_COMMENTS_STATUS:-0}" \
    bash "$REPO_ROOT/scripts/workflows/weekly-review/fetch-weekly-review-json-from-issue.sh" \
    2099-W50 "$TEST_ROOT/weekly-review.json"
}

@test "weekly issue recovery selects the newest snapshot across all comment pages" {
  cat >"$GH_COMMENTS_FILE" <<'EOF'
[
  [
    {
      "id": 10,
      "body": "<!-- weekly-review:json:2099-W50 run:10 attempt:1 -->\n```json\n{\"run_week\":\"2099-W50\",\"value\":\"old\"}\n```"
    }
  ],
  [
    {
      "id": 20,
      "body": "<!-- weekly-review:json:2099-W50 run:20 attempt:1 -->\n```json\n{\"run_week\":\"2099-W50\",\"value\":\"new\"}\n```"
    }
  ]
]
EOF

  run_issue_restore

  [ "$status" -eq 0 ]
  [ "$(jq -r .value "$TEST_ROOT/weekly-review.json")" = new ]
  grep -Fq \
    "api --paginate --slurp repos/owner/repo/issues/204/comments?per_page=100" \
    "$GH_CALLS_FILE"
}

@test "weekly issue recovery reports a missing matching snapshot" {
  cat >"$GH_COMMENTS_FILE" <<'EOF'
[
  [
    {
      "id": 10,
      "body": "<!-- weekly-review:json:2099-W49 run:10 attempt:1 -->\n```json\n{\"run_week\":\"2099-W49\"}\n```"
    }
  ]
]
EOF

  run_issue_restore

  [ "$status" -eq 1 ]
  [[ "$output" == *"No JSON snapshot comment on issue #204 for 2099-W50"* ]]
  [ ! -e "$TEST_ROOT/weekly-review.json" ]
}

@test "weekly issue recovery preserves comment API permission failures" {
  printf '[]\n' >"$GH_COMMENTS_FILE"
  GH_COMMENTS_STATUS=1

  run_issue_restore

  [ "$status" -eq 1 ]
  [[ "$output" == *"HTTP 403: Resource not accessible by integration"* ]]
  [[ "$output" != *"No JSON snapshot comment"* ]]
  [ ! -e "$TEST_ROOT/weekly-review.json" ]
}

@test "weekly fix job grants only the artifact read permission it needs" {
  run python3 - "$REPO_ROOT/.github/workflows/agent-weekly-review.yml" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
fix = text.split("  weekly-fix:", 1)[1]
permissions = fix.split("    env:", 1)[0]
actual = dict(re.findall(r"^      ([a-z-]+): (read|write|none)$", permissions, re.MULTILINE))
assert actual == {
    "actions": "read",
    "contents": "write",
    "pull-requests": "write",
    "issues": "write",
}
PY

  [ "$status" -eq 0 ]
}
