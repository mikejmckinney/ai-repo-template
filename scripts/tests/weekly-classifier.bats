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

@test "weekly LLM output rejects retired output buckets" {
  for bucket in adr_updates context_pack_updates; do
    jq --arg bucket "$bucket" '. + {($bucket): []}' "$FIXTURE" >"$TEST_ROOT/review.json"

    run python3 "$WEEKLY_DIR/validate-weekly-review.py" "$TEST_ROOT/review.json"

    [ "$status" -eq 1 ]
    [[ "$output" == *"$bucket is retired"* ]]
  done
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

@test "weekly umbrella merge upgrades legacy details and adds hybrid summary" {
  python3 "$WEEKLY_DIR/build-weekly-review-batch.py" \
    2026-W24 2026-06-14 "$FIXTURE" >"$TEST_ROOT/weekly.json"
  python3 "$WEEKLY_DIR/render-umbrella-findings.py" \
    "$TEST_ROOT/weekly.json" owner/repo deadbeef "$TEST_ROOT/details.md"
  python3 "$WEEKLY_DIR/render-umbrella-findings.py" \
    "$TEST_ROOT/weekly.json" owner/repo deadbeef "$TEST_ROOT/rows.md" --summary
  printf '%s\n' '<!-- weekly-review:2026-W24 -->' '## Findings' '' '## Meta' >"$TEST_ROOT/body.md"

  run python3 "$WEEKLY_DIR/merge-umbrella-content.py" \
    "$TEST_ROOT/body.md" "$TEST_ROOT/rows.md" "$TEST_ROOT/details.md" "$TEST_ROOT/merged.md"
  [ "$status" -eq 0 ]

  run grep -F '## Triage summary' "$TEST_ROOT/merged.md"
  [ "$status" -eq 0 ]
  run grep -F '| meta-harness | edge | trivial | true | should-fix |' "$TEST_ROOT/merged.md"
  [ "$status" -eq 0 ]
  run grep -F '## Finding details' "$TEST_ROOT/merged.md"
  [ "$status" -eq 0 ]
  [ "$(grep -Fc '<!-- weekly-review:finding:repo-invariant-052-missing-link -->' "$TEST_ROOT/merged.md")" -eq 1 ]
}

@test "weekly superseded prefilter uses evidence paths without removing findings" {
  mkdir -p "$TEST_ROOT/scripts/lib"
  printf '%s\n' present >"$TEST_ROOT/scripts/lib/existing.sh"
  cat >"$TEST_ROOT/weekly.json" <<'EOF'
{
  "run_week": "2026-W24",
  "findings": [
    {
      "category": "follow_up_issues",
      "title": "Missing helper",
      "body": "scripts/lib/existing.sh is missing",
      "dedupe_key": "missing-helper",
      "evidence": ["scripts/lib/existing.sh"],
      "repro_steps": ["Check scripts/lib/existing.sh"]
    }
  ]
}
EOF

  run python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/mark-superseded-findings.py" \
    "$TEST_ROOT/weekly.json" --repo-root "$TEST_ROOT" --mode weekly
  [ "$status" -eq 0 ]
  run jq -e '.findings | length == 1 and .[0].superseded_on_main == true' "$TEST_ROOT/weekly.json"
  [ "$status" -eq 0 ]
  run jq -e '.superseded_findings[0].dedupe_key == "missing-helper"' "$TEST_ROOT/weekly.json"
  [ "$status" -eq 0 ]
}
