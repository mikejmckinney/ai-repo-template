#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SELECTOR="$REPO_ROOT/scripts/select-verification-impact.py"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/scripts/tests" "$TEST_ROOT/scripts/checks" "$TEST_ROOT/.config" \
    "$TEST_ROOT/policy" "$TEST_ROOT/labels"
  touch "$TEST_ROOT/policy/rules.md" "$TEST_ROOT/labels/catalog.txt"
  printf '# policy/rules.md\n' >"$TEST_ROOT/scripts/tests/provider.bats"
  printf '# labels/catalog.txt\n' >"$TEST_ROOT/scripts/tests/labels.bats"
  printf '# policy/rules.md\n' >"$TEST_ROOT/scripts/checks/049-policy.sh"
  printf '# labels/catalog.txt\n' >"$TEST_ROOT/scripts/checks/052-labels.sh"
  cat >"$TEST_ROOT/.config/verification-impact.json" <<'JSON'
{"version":1,"fullPatterns":["shared/**"],"mappings":[
  {"patterns":["policy/rules.md"],"bats":["scripts/tests/provider.bats"],"checks":["scripts/checks/049-policy.sh"]},
  {"patterns":["labels/catalog.txt"],"bats":["scripts/tests/labels.bats"],"checks":["scripts/checks/052-labels.sh"]}
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

@test "manifest consumers must retain evidence of the mapped path" {
  printf '# unrelated\n' >"$TEST_ROOT/scripts/tests/provider.bats"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unproven mapping"* ]]
}

@test "glob mappings accept evidence from a matching repository path" {
  printf '# ${repo_root}/policy/rules.md.\n' >"$TEST_ROOT/scripts/tests/provider.bats"
  jq '.mappings[0].patterns=["policy/*.md"]' \
    "$TEST_ROOT/.config/verification-impact.json" >"$TEST_ROOT/glob.json"
  mv "$TEST_ROOT/glob.json" "$TEST_ROOT/.config/verification-impact.json"

  select_paths policy/rules.md
  [ "$status" -eq 0 ]
  [ "$(jq -r .mode <<<"$output")" = selected ]
}

@test "mapping evidence must name an existing repository path" {
  rm "$TEST_ROOT/policy/rules.md"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unproven mapping: scripts/tests/provider.bats"* ]]
}

@test "glob mapping text is not concrete consumer evidence" {
  printf '# policy/*.md\n' >"$TEST_ROOT/scripts/tests/provider.bats"
  jq '.mappings[0].patterns=["policy/*.md"]' \
    "$TEST_ROOT/.config/verification-impact.json" >"$TEST_ROOT/glob.json"
  mv "$TEST_ROOT/glob.json" "$TEST_ROOT/.config/verification-impact.json"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unproven mapping: scripts/tests/provider.bats"* ]]
}

@test "literal mapping evidence requires an exact path token" {
  printf '# policy/rules.md.bak\n' >"$TEST_ROOT/scripts/tests/provider.bats"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unproven mapping: scripts/tests/provider.bats"* ]]
}

@test "ordinary path prefixes are not treated as repository-root variables" {
  mkdir -p "$TEST_ROOT/vendor/policy"
  touch "$TEST_ROOT/vendor/policy/rules.md"
  printf '# vendor/policy/rules.md\n' >"$TEST_ROOT/scripts/tests/provider.bats"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unproven mapping: scripts/tests/provider.bats"* ]]
}

@test "mapping evidence may name only declared consumers" {
  jq '.mappings[0].evidence={"scripts/tests/labels.bats":"policy/rules.md"}' \
    "$TEST_ROOT/.config/verification-impact.json" >"$TEST_ROOT/invalid.json"
  mv "$TEST_ROOT/invalid.json" "$TEST_ROOT/.config/verification-impact.json"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"mapping evidence must name only declared consumers"* ]]
}

@test "mapping evidence files must exist" {
  printf '# scripts/missing.py\n' >"$TEST_ROOT/scripts/tests/provider.bats"
  jq '.mappings[0].evidence={"scripts/tests/provider.bats":"scripts/missing.py"}' \
    "$TEST_ROOT/.config/verification-impact.json" >"$TEST_ROOT/invalid.json"
  mv "$TEST_ROOT/invalid.json" "$TEST_ROOT/.config/verification-impact.json"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"missing mapping evidence: scripts/missing.py"* ]]
}

@test "mapping evidence files must reference the mapped path" {
  mkdir -p "$TEST_ROOT/scripts"
  printf '# scripts/evidence.py\n' >"$TEST_ROOT/scripts/tests/provider.bats"
  printf '# unrelated\n' >"$TEST_ROOT/scripts/evidence.py"
  jq '.mappings[0].evidence={"scripts/tests/provider.bats":"scripts/evidence.py"}' \
    "$TEST_ROOT/.config/verification-impact.json" >"$TEST_ROOT/invalid.json"
  mv "$TEST_ROOT/invalid.json" "$TEST_ROOT/.config/verification-impact.json"

  select_paths policy/rules.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unproven mapping: scripts/tests/provider.bats via scripts/evidence.py"* ]]
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

@test "shipped impact mappings retain consumer evidence" {
  run python3 "$SELECTOR" --repo "$REPO_ROOT" --changed-path .config/mcp-inventory.json
  [ "$status" -eq 0 ]
  [ "$(jq -r .mode <<<"$output")" = selected ]
  [ "$(jq -r '.bats | join("|")' <<<"$output")" = "scripts/tests/generated-mcp-configs.bats|scripts/tests/provider-integrations.bats" ]
  [ "$(jq -r '.checks | join("|")' <<<"$output")" = scripts/checks/056-generated-governance-surfaces.sh ]
}
