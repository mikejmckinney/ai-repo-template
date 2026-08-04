#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GENERATOR="$REPO_ROOT/scripts/generate-pap-catalog.py"
  ISSUE_PLAN_GENERATOR="$REPO_ROOT/scripts/generate-issue-plans.py"
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

@test "issue plan generated output is current" {
  run python3 "$ISSUE_PLAN_GENERATOR" --repo "$REPO_ROOT" --check

  [ "$status" -eq 0 ]
}

@test "issue plans prompt for keyed-state and delivery-boundary semantics" {
  paths=(
    ".github/templates/issue-implementation-plan.md"
    ".github/ISSUE_TEMPLATE/bug_report.md"
    ".github/ISSUE_TEMPLATE/feature_request.md"
    ".github/ISSUE_TEMPLATE/agent_init.md"
  )

  for path in "${paths[@]}"; do
    grep -Fq "### Keyed-state semantics (conditional)" "$REPO_ROOT/$path"
    grep -Fq "identical retry" "$REPO_ROOT/$path"
    grep -Fq "duplicate legacy records" "$REPO_ROOT/$path"
    grep -Fq "### Delivery boundaries" "$REPO_ROOT/$path"
    grep -Fq "one PR, stacked PRs, or separate PRs" "$REPO_ROOT/$path"
  done
}

@test "shared review contract requires the conditional keyed-state matrix" {
  contract="$REPO_ROOT/.github/prompts/shared-review-lenses.md"

  grep -Fq "## Persisted keyed-state matrix" "$contract"
  grep -Fq "first write" "$contract"
  grep -Fq "identical retry" "$contract"
  grep -Fq "changed retry" "$contract"
  grep -Fq "unrelated-key preservation" "$contract"
  grep -Fq "duplicate legacy records" "$contract"
  grep -Fq "missing-field compatibility" "$contract"
}

@test "post-compaction guidance re-reads committed design contracts" {
  grep -Fq "committed failing tests" "$REPO_ROOT/AGENTS.md"
  grep -Fq "current issue and PR design contract" "$REPO_ROOT/AGENTS.md"
}

@test "command guide distinguishes focused and broader verification" {
  grep -Fq "scripts/verify-local.sh" "$REPO_ROOT/AI_REPO_GUIDE.md"
  grep -Fq "direct component commands for focused local verification" "$REPO_ROOT/AI_REPO_GUIDE.md"
  grep -Fq 'scripts/verify-local.sh --full` only when' "$REPO_ROOT/AI_REPO_GUIDE.md"
}
