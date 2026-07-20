#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GENERATOR="$REPO_ROOT/scripts/generate-pap-catalog.py"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/docs/guides"
  cp "$REPO_ROOT/AGENTS.md" "$TEST_ROOT/AGENTS.md"
  cp "$REPO_ROOT/docs/guides/repo-orchestration-patterns-reference.md" \
    "$TEST_ROOT/docs/guides/repo-orchestration-patterns-reference.md"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "P/AP catalog generated output is current" {
  run python3 "$GENERATOR" --repo "$REPO_ROOT" --check

  [ "$status" -eq 0 ]
}

@test "P/AP catalog check identifies stale output and repair command" {
  sed -i '/generated:pap-catalog:end/i stale generated catalog' \
    "$TEST_ROOT/AGENTS.md"

  run python3 "$GENERATOR" --repo "$TEST_ROOT" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/guides/repo-orchestration-patterns-reference.md"* ]]
  [[ "$output" == *"scripts/generate-pap-catalog.py"* ]]
}

@test "P/AP catalog generation is deterministic and idempotent" {
  sed -i '/generated:pap-catalog:end/i stale generated catalog' \
    "$TEST_ROOT/AGENTS.md"

  run python3 "$GENERATOR" --repo "$TEST_ROOT"
  [ "$status" -eq 0 ]
  first_checksum="$(sha256sum "$TEST_ROOT/AGENTS.md")"

  run python3 "$GENERATOR" --repo "$TEST_ROOT"
  [ "$status" -eq 0 ]
  [ "$first_checksum" = "$(sha256sum "$TEST_ROOT/AGENTS.md")" ]
}

@test "P/AP catalog generation rejects missing markers" {
  sed -i '/generated:pap-catalog:begin/d' "$TEST_ROOT/AGENTS.md"

  run python3 "$GENERATOR" --repo "$TEST_ROOT"

  [ "$status" -eq 2 ]
  [[ "$output" == *"missing marker"* ]]
}
