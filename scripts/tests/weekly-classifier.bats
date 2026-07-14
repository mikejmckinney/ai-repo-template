#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  WEEKLY_DIR="$REPO_ROOT/scripts/workflows/weekly-review"
  FIXTURE="$REPO_ROOT/scripts/tests/fixtures/weekly-review/sample-review.json"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/weekly-classifier-test.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "weekly batch derives canonical priority fields" {
  run python3 "$WEEKLY_DIR/validate-weekly-review.py" "$FIXTURE"
  [ "$status" -eq 0 ]

  run bash -c 'python3 "$1/build-weekly-review-batch.py" 2026-W24 2026-06-14 "$2" >"$3"' \
    _ "$WEEKLY_DIR" "$FIXTURE" "$TEST_ROOT/weekly.json"
  [ "$status" -eq 0 ]

  run jq -e '.findings[0] | .priority_band == "should-fix" and .impact == "meta-harness"' \
    "$TEST_ROOT/weekly.json"
  [ "$status" -eq 0 ]

  run python3 "$WEEKLY_DIR/validate-weekly-review-batch.py" "$TEST_ROOT/weekly.json"
  [ "$status" -eq 0 ]
}

@test "weekly LLM output rejects deprecated severity" {
  jq '.follow_up_issues[0] += {severity: "low"}' "$FIXTURE" >"$TEST_ROOT/review.json"

  run python3 "$WEEKLY_DIR/validate-weekly-review.py" "$TEST_ROOT/review.json"

  [ "$status" -eq 1 ]
  [[ "$output" == *"severity is deprecated"* ]]
}

@test "weekly LLM output rejects emitted priority band" {
  jq '.follow_up_issues[0] += {priority_band: "should-fix"}' "$FIXTURE" >"$TEST_ROOT/review.json"

  run python3 "$WEEKLY_DIR/validate-weekly-review.py" "$TEST_ROOT/review.json"

  [ "$status" -eq 1 ]
  [[ "$output" == *"priority_band is derived"* ]]
}

@test "weekly detail renderer shows classifier fields and reproduction" {
  python3 "$WEEKLY_DIR/build-weekly-review-batch.py" \
    2026-W24 2026-06-14 "$FIXTURE" >"$TEST_ROOT/weekly.json"

  run python3 "$WEEKLY_DIR/render-umbrella-findings.py" \
    "$TEST_ROOT/weekly.json" owner/repo deadbeef "$TEST_ROOT/findings.md"
  [ "$status" -eq 0 ]

  run grep -F '**Band:** `should-fix`' "$TEST_ROOT/findings.md"
  [ "$status" -eq 0 ]
  run grep -F '**Triage:** impact `meta-harness`' "$TEST_ROOT/findings.md"
  [ "$status" -eq 0 ]
  run grep -F '**Reproduction:**' "$TEST_ROOT/findings.md"
  [ "$status" -eq 0 ]
  run grep -F '**Severity:**' "$TEST_ROOT/findings.md"
  [ "$status" -eq 1 ]
}
