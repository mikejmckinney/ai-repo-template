#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SELECTOR="$REPO_ROOT/scripts/select-verification-impact.py"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/scripts/tests" "$TEST_ROOT/scripts/checks" "$TEST_ROOT/.config"
  touch "$TEST_ROOT/scripts/tests/labels.bats" "$TEST_ROOT/scripts/tests/provider.bats"
  touch "$TEST_ROOT/scripts/checks/049-policy.sh" "$TEST_ROOT/scripts/checks/052-labels.sh"
  cat >"$TEST_ROOT/.config/verification-impact.json" <<'JSON'
{"version":1,"fullPatterns":["shared/**"],"mappings":[
  {"patterns":["policy/**"],"bats":["scripts/tests/provider.bats"],"checks":["scripts/checks/049-policy.sh"]},
  {"patterns":["labels/**"],"bats":["scripts/tests/labels.bats"],"checks":["scripts/checks/052-labels.sh"]}
]}
JSON
}

teardown() {
  rm -rf "$TEST_ROOT"
}

select_paths() {
  local args=()
  for path in "$@"; do args+=(--changed-path "$path"); done
  run python3 "$SELECTOR" --repo "$TEST_ROOT" "${args[@]}"
}

@test "bounded and overlapping mappings union deterministic consumers" {
  select_paths policy/rules.md labels/catalog.txt
  [ "$status" -eq 0 ]
  [ "$(jq -r .mode <<<"$output")" = selected ]
  [ "$(jq -r '.bats | join("|")' <<<"$output")" = "scripts/tests/labels.bats|scripts/tests/provider.bats" ]
  [ "$(jq -r '.checks | join("|")' <<<"$output")" = "scripts/checks/049-policy.sh|scripts/checks/052-labels.sh" ]
}

@test "changed consumers always select themselves" {
  select_paths scripts/tests/provider.bats scripts/checks/052-labels.sh
  [ "$status" -eq 0 ]
  [ "$(jq -r '.bats[0]' <<<"$output")" = scripts/tests/provider.bats ]
  [ "$(jq -r '.checks[0]' <<<"$output")" = scripts/checks/052-labels.sh ]
}

@test "deleted consumers force full verification" {
  select_paths scripts/tests/deleted.bats
  [ "$status" -eq 0 ]
  [ "$(jq -r .mode <<<"$output")" = full ]
  [ "$(jq -r '.fallbackReasons[0]' <<<"$output")" = "deleted-consumer:scripts/tests/deleted.bats" ]
}

@test "unknown shared and selector changes fall back to full verification" {
  for path in unknown/file.txt shared/tool.sh scripts/select-verification-impact.py .config/verification-impact.json; do
    select_paths "$path"
    [ "$status" -eq 0 ]
    [ "$(jq -r .mode <<<"$output")" = full ]
    [ "$(jq -r '.fallbackReasons | length' <<<"$output")" -gt 0 ]
  done
}

@test "invalid manifests fail instead of producing zero coverage" {
  jq '.mappings[0].bats=["scripts/tests/missing.bats"]' \
    "$TEST_ROOT/.config/verification-impact.json" >"$TEST_ROOT/invalid.json"
  mv "$TEST_ROOT/invalid.json" "$TEST_ROOT/.config/verification-impact.json"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"missing consumer"* ]]
}

@test "an empty changed-path set cannot succeed with zero coverage" {
  run python3 "$SELECTOR" --repo "$TEST_ROOT"
  [ "$status" -eq 0 ]
  [ "$(jq -r .mode <<<"$output")" = full ]
}

@test "explicit full mode overrides otherwise bounded selection" {
  run python3 "$SELECTOR" --repo "$TEST_ROOT" --changed-path policy/rules.md --force-full event:push
  [ "$status" -eq 0 ]
  [ "$(jq -r .mode <<<"$output")" = full ]
  [ "$(jq -r '.fallbackReasons[0]' <<<"$output")" = event:push ]
}

@test "test.sh selected mode runs only the requested canonical module" {
  run bash "$REPO_ROOT/test.sh" scripts/checks/145-workflow-secret-guard.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checking workflow secret-presence guards"* ]]
  [[ "$output" != *"Checking public entrypoints"* ]]
}

@test "CI preserves one required gate while executing the selected plan" {
  workflow="$REPO_ROOT/.github/workflows/ci-tests.yml"
  grep -q 'scripts/select-verification-impact.py' "$workflow"
  grep -q 'github.event.pull_request.head.sha || github.sha' "$workflow"
  grep -q 'verification-plan.json' "$workflow"
  grep -q 'GITHUB_STEP_SUMMARY' "$workflow"
  grep -q 'bats --jobs 12 "${selected\[@\]}"' "$workflow"
  grep -q './test.sh "${selected\[@\]}"' "$workflow"
  grep -q 'Gate on combined test results' "$workflow"
}
