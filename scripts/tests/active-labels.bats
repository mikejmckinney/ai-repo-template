#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  VALIDATOR="$REPO_ROOT/scripts/validate-active-labels.py"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/scripts/setup" "$TEST_ROOT/.github/workflows"
  cp "$REPO_ROOT/scripts/setup/40-ensure-labels.sh" \
    "$TEST_ROOT/scripts/setup/40-ensure-labels.sh"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "active structured label references are declared" {
  run python3 "$VALIDATOR" --repo "$REPO_ROOT"

  [ "$status" -eq 0 ]
}

@test "undeclared workflow label fails with its path and label" {
  printf '%s\n' "name: labels" "on: push" "jobs:" "  create:" \
    "    labels: ['undeclared-label']" \
    >"$TEST_ROOT/.github/workflows/labels.yml"

  run python3 "$VALIDATOR" --repo "$TEST_ROOT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"undeclared-label"* ]]
  [[ "$output" == *".github/workflows/labels.yml"* ]]
}

@test "arbitrary workflow prose is outside the label validator boundary" {
  printf '%s\n' "name: prose" "on: push" "jobs:" "  test:" \
    "    runs-on: ubuntu-latest" "    steps:" \
    "      - run: echo undeclared-label" \
    >"$TEST_ROOT/.github/workflows/prose.yml"

  run python3 "$VALIDATOR" --repo "$TEST_ROOT"

  [ "$status" -eq 0 ]
}
