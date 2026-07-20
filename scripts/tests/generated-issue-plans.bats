#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GENERATOR="$REPO_ROOT/scripts/generate-issue-plans.py"
  TEST_ROOT="$(mktemp -d)"
  mkdir -p "$TEST_ROOT/.github/ISSUE_TEMPLATE" "$TEST_ROOT/.github/templates"
  cp "$REPO_ROOT/.github/templates/issue-implementation-plan.md" \
    "$TEST_ROOT/.github/templates/issue-implementation-plan.md"
  for template in bug_report feature_request agent_init; do
    cp "$REPO_ROOT/.github/ISSUE_TEMPLATE/${template}.md" \
      "$TEST_ROOT/.github/ISSUE_TEMPLATE/${template}.md"
  done
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "issue-plan generated blocks are current" {
  run python3 "$GENERATOR" --repo "$REPO_ROOT" --check

  [ "$status" -eq 0 ]
}

@test "issue-plan check reports every stale template" {
  sed -i '/implementation-plan:v2:end/i stale plan block' \
    "$TEST_ROOT/.github/ISSUE_TEMPLATE/bug_report.md"
  sed -i '/implementation-plan:v2:end/i stale plan block' \
    "$TEST_ROOT/.github/ISSUE_TEMPLATE/feature_request.md"

  run python3 "$GENERATOR" --repo "$TEST_ROOT" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"bug_report.md"* ]]
  [[ "$output" == *"feature_request.md"* ]]
  [[ "$output" == *"scripts/generate-issue-plans.py"* ]]
}

@test "issue-plan generation preserves template-specific content" {
  before="$(sed -n '1,/implementation-plan:v2:begin/p' \
    "$TEST_ROOT/.github/ISSUE_TEMPLATE/agent_init.md")"
  sed -i '/implementation-plan:v2:end/i stale plan block' \
    "$TEST_ROOT/.github/ISSUE_TEMPLATE/agent_init.md"

  run python3 "$GENERATOR" --repo "$TEST_ROOT"

  [ "$status" -eq 0 ]
  [ "$before" = "$(sed -n '1,/implementation-plan:v2:begin/p' \
    "$TEST_ROOT/.github/ISSUE_TEMPLATE/agent_init.md")" ]
  run python3 "$GENERATOR" --repo "$TEST_ROOT" --check
  [ "$status" -eq 0 ]
}

@test "issue-plan generation rejects missing markers" {
  sed -i '/implementation-plan:v2:end/d' \
    "$TEST_ROOT/.github/ISSUE_TEMPLATE/bug_report.md"

  run python3 "$GENERATOR" --repo "$TEST_ROOT"

  [ "$status" -eq 2 ]
  [[ "$output" == *"missing marker"* ]]
}
