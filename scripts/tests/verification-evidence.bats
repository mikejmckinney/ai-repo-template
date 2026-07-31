#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  VALIDATOR="$REPO_ROOT/scripts/validate-verification-evidence.py"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

write_outcome() {
  local target="$1"
  local sandbox_required="$2"
  local sandbox_issue="$3"
  local sandbox_pr="$4"

  cat >"$TMP_DIR/pr.md" <<EOF
## User outcome validation — PRIMARY

**Problem statement tested:** yes

**User outcome / 15-minute test performed:** yes

**Result:** problem statement resolved

## Sandbox dogfood evidence

E2E target: $target
Sandbox required: $sandbox_required
Reason: representative test constraint

Sandbox issue: $sandbox_issue
Sandbox PR: $sandbox_pr
EOF
}

@test "branch E2E accepts reasoned sandbox N/A" {
  write_outcome \
    "PR branch" \
    "no" \
    "N/A — branch E2E exercises the complete user journey" \
    "N/A — no behavior depends on a default-branch trigger"

  run python3 "$VALIDATOR" \
    --change-class "code-or-docs" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"verification evidence is valid"* ]]
}

@test "default-branch-only workflow rejects sandbox N/A" {
  write_outcome \
    "sandbox repo" \
    "yes" \
    "N/A — branch tests passed" \
    "N/A — branch tests passed"

  run python3 "$VALIDATOR" \
    --change-class "default-branch-only workflow" \
    --verification-target "sandbox repo" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"requires real sandbox issue and PR URLs"* ]]
}

@test "default-branch-only workflow accepts distinct sandbox URLs" {
  write_outcome \
    "sandbox repo" \
    "yes" \
    "https://github.com/example/project-sandbox/issues/12" \
    "https://github.com/example/project-sandbox/pull/13"

  run python3 "$VALIDATOR" \
    --change-class "default-branch-only workflow" \
    --verification-target "sandbox repo" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 0 ]
}

@test "supporting checks cannot replace user-outcome evidence" {
  cat >"$TMP_DIR/pr.md" <<'EOF'
## User outcome validation — PRIMARY

**Problem statement tested:** no

**User outcome / 15-minute test performed:** no

**Result:** blocked

## Sandbox dogfood evidence

E2E target: PR branch
Sandbox required: no
Reason: representative test constraint

Sandbox issue: N/A — branch E2E exercises the complete user journey
Sandbox PR: N/A — no behavior depends on a default-branch trigger
EOF

  run python3 "$VALIDATOR" \
    --change-class "code-or-docs" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"user-outcome validation is incomplete"* ]]
}

@test "mixed change requires an explicit default-branch constraint" {
  write_outcome \
    "PR branch" \
    "no" \
    "N/A — branch E2E exercises the complete user journey" \
    "N/A — no behavior depends on a default-branch trigger"

  run python3 "$VALIDATOR" \
    --change-class "mixed" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"mixed changes require --default-branch-constrained"* ]]
}

@test "default-branch-constrained mixed change rejects branch N/A" {
  write_outcome \
    "PR branch" \
    "no" \
    "N/A — branch E2E exercises the complete user journey" \
    "N/A — no behavior depends on a default-branch trigger"

  run python3 "$VALIDATOR" \
    --change-class "mixed" \
    --default-branch-constrained "yes" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"default-branch-constrained changes must target sandbox repo or both"* ]]
  [[ "$output" == *"requires real sandbox issue and PR URLs"* ]]
}

@test "branch-testable mixed change accepts reasoned sandbox N/A" {
  write_outcome \
    "PR branch" \
    "no" \
    "N/A — pull request event exercises the changed behavior" \
    "N/A — default-branch trigger wiring is unchanged"

  run python3 "$VALIDATOR" \
    --change-class "mixed" \
    --default-branch-constrained "no" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"verification evidence is valid"* ]]
}

@test "default-branch-constrained mixed change accepts sandbox URLs" {
  write_outcome \
    "sandbox repo" \
    "yes" \
    "https://github.com/example/project-sandbox/issues/12" \
    "https://github.com/example/project-sandbox/pull/13"

  run python3 "$VALIDATOR" \
    --change-class "mixed" \
    --default-branch-constrained "yes" \
    --verification-target "sandbox repo" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 0 ]
}

@test "CLI help routes mixed changes by changed-behavior constraint" {
  run python3 "$VALIDATOR" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"behavior requires default-branch execution"* ]]
  [[ "$output" != *"most restrictive detected path"* ]]
}
