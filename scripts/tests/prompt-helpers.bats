#!/usr/bin/env bats
#
# prompt_helpers.py cap-json and select-context behavior.

bats_require_minimum_version 1.7.0
export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-120}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  PROMPT_HELPERS="$REPO_ROOT/scripts/workflows/lib/prompt_helpers.py"
  export PROMPT_HELPERS
}

setup() {
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/prompt-helpers.XXXXXX")"
  export TMP_DIR
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "cap-json keeps newest review comments when trimming arrays" {
  python3 - "$TMP_DIR/reviews.json" <<'PY' >/dev/null
import json, sys
from pathlib import Path
items = [{"id": i, "body": f"comment-{i}"} for i in range(20)]
Path(sys.argv[1]).write_text(json.dumps(items), encoding="utf-8")
PY

  run python3 "$PROMPT_HELPERS" cap-json \
    --input "$TMP_DIR/reviews.json" \
    --jq-filter 'map({id, body})' \
    --max-bytes 400
  [ "$status" -eq 0 ]
  last_id="$(jq -r '.[-1].id' <<<"$output")"
  [ "$last_id" = "19" ]
}

@test "cap-json drops diff_hunk before returning empty array" {
  cat >"$TMP_DIR/inline.json" <<'EOF'
[{"id":1,"body":"short","diff_hunk":"@@\n+aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]
EOF

  run python3 "$PROMPT_HELPERS" cap-json \
    --input "$TMP_DIR/inline.json" \
    --jq-filter 'map({id, body, diff_hunk})' \
    --max-bytes 200
  [ "$status" -eq 0 ]
  [ "$(jq 'length' <<<"$output")" -gt 0 ]
  [ "$(jq -r '.[0].diff_hunk // empty' <<<"$output")" = "" ]
}

@test "cap-json preserves null review authors with the production filter" {
  cat >"$TMP_DIR/reviews.json" <<'EOF'
[{"id":1,"user":null,"body":"automated review"}]
EOF

  run python3 "$PROMPT_HELPERS" cap-json \
    --input "$TMP_DIR/reviews.json" \
    --jq-filter 'map({id, user: (.user?.login // null), body})' \
    --max-bytes 500
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0] | has("user")' <<<"$output")" = "true" ]
  [ "$(jq -r '.[0].user == null' <<<"$output")" = "true" ]
}

@test "select-context includes the shared review lenses" {
  printf 'AGENTS.md\n' >"$TMP_DIR/changed.txt"
  run python3 "$PROMPT_HELPERS" select-context \
    --profile pr-review \
    --changed-files "$TMP_DIR/changed.txt"
  [ "$status" -eq 0 ]
  [ "$output" = $'AGENTS.md\n.github/prompts/shared-review-lenses.md\n.github/pull_request_template.md' ]
}

@test "select-context adds task-specific workflow guidance" {
  printf '.github/workflows/ci-tests.yml\n' >"$TMP_DIR/changed.txt"
  run python3 "$PROMPT_HELPERS" select-context \
    --profile pr-review \
    --changed-files "$TMP_DIR/changed.txt"
  [ "$status" -eq 0 ]
  grep -qxF 'docs/guides/agent-pipeline.md' <<<"$output"
}

@test "cap-json warns on stderr when returning empty array" {
  python3 - "$TMP_DIR/huge.json" <<'PY' >/dev/null
import json, sys
from pathlib import Path
items = [{"id": i, "body": "x" * 20000} for i in range(5)]
Path(sys.argv[1]).write_text(json.dumps(items), encoding="utf-8")
PY

  run --separate-stderr python3 "$PROMPT_HELPERS" cap-json \
    --input "$TMP_DIR/huge.json" \
    --jq-filter 'map({id, body})' \
    --max-bytes 30
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
  grep -q '::warning::cap-json' <<<"$stderr"
}

@test "build-json-snapshot-comment truncates oversized JSON with warning" {
  BUILD_JSON="$REPO_ROOT/scripts/workflows/lib/build-json-snapshot-comment.py"
  python3 - "$TMP_DIR/large.json" <<'PY' >/dev/null
import json, sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({"items": ["x" * 80000]}), encoding="utf-8")
PY

  run --separate-stderr python3 "$BUILD_JSON" \
    --marker "<!-- test:marker -->" \
    --heading "Test snapshot" \
    --intro "Test intro." \
    --json-file "$TMP_DIR/large.json" \
    --max-bytes 2000
  [ "$status" -eq 0 ]
  grep -q 'TRUNCATED' <<<"$output"
  grep -q '::warning::JSON snapshot truncated' <<<"$stderr"
  comment="$output"
  run python3 -c '
import json
import re
import sys

match = re.search(r"```json\s*(.*?)\s*```", sys.stdin.read(), re.DOTALL)
assert match is not None
payload = json.loads(match.group(1))
assert payload["snapshot_status"] == "TRUNCATED"
assert payload["original_bytes"] > 2000
' <<<"$comment"
  [ "$status" -eq 0 ]
}
