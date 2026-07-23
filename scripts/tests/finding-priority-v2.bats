#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLASSIFIER="$REPO_ROOT/scripts/workflows/postmerge-retro/classify-finding-priority.py"
}

classify_v2() {
  python3 "$CLASSIFIER" \
    --triage-version 2 \
    --impact incorrect-behavior \
    --impact-magnitude "$1" \
    --trigger "$2" \
    --affected-scope "$3" \
    --reversibility "$4" \
    --fix-cost "$5" \
    --confidence "$6" \
    --uncertainty "$7" \
    --surface "$8"
}

@test "v2 classifies common material broad hard failures as fix-now" {
  run classify_v2 material common broad hard moderate high none formal

  [ "$status" -eq 0 ]
  jq -e '.triage_version == 2 and .priority_band == "fix-now" and .surface_action == "request-changes"' <<<"$output"
}

@test "v2 keeps advisory authority non-blocking for the same finding" {
  run classify_v2 material common broad hard moderate high none advisory

  [ "$status" -eq 0 ]
  jq -e '.priority_band == "fix-now" and .surface_action == "optional-input"' <<<"$output"
}

@test "v2 defers fringe bounded reversible failures with expensive mitigation" {
  run classify_v2 bounded fringe isolated easy large high none formal

  [ "$status" -eq 0 ]
  jq -e '.priority_band == "defer" and .surface_action == "no-action"' <<<"$output"
}

@test "v2 low confidence cannot produce a fix-now recommendation" {
  run classify_v2 critical common broad hard moderate low "trigger frequency is unverified" formal

  [ "$status" -eq 0 ]
  jq -e '.priority_band == "should-fix" and .surface_action == "recommend-fix"' <<<"$output"
}

@test "v2 requires every normalized AP11 field" {
  run python3 "$CLASSIFIER" \
    --triage-version 2 \
    --impact incorrect-behavior \
    --trigger common \
    --fix-cost moderate

  [ "$status" -ne 0 ]
  [[ "$output" == *"impact-magnitude"* ]]
}

@test "legacy v1 classification remains stable for persisted findings" {
  run python3 "$CLASSIFIER" \
    --impact incorrect-behavior \
    --trigger common \
    --fix-cost moderate

  [ "$status" -eq 0 ]
  [ "$output" = "fix-now" ]
}
