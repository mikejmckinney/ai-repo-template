#!/usr/bin/env bats
# ADR-026 compliance schema fixture tests.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
}

@test "compliance schema examples parse and validate" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-examples.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"validated"* ]]
}

@test "explicit relative compliance schema example path validates" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-examples.py docs/compliance_schemas.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"validated"* ]]
  [[ "$output" != *"ValueError"* ]]
}

@test "compliance fixtures separate valid and invalid evidence" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-fixtures.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"valid"* ]]
  [[ "$output" == *"invalid"* ]]
}

@test "invalid single compliance fixture fails" {
  cd "$REPO_ROOT"
  run python3 scripts/validate-compliance-fixtures.py --single scripts/tests/fixtures/compliance/invalid/overlay-version.yml
  [ "$status" -ne 0 ]
  [[ "$output" == *"overlay_version is not allowed"* ]]
  [[ "$output" != *"ValueError"* ]]
}
