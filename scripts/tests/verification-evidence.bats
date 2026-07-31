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
  local default_branch_constrained="${3:-no}"
  local reason="${4-Synthetic PR fixtures exercise the changed artifact paths without default-branch state}"

  cat >"$TMP_DIR/pr.md" <<EOF
## User outcome validation — PRIMARY

**Problem statement tested:** yes

**User outcome / 15-minute test performed:** yes

**Result:** problem statement resolved

## Sandbox dogfood evidence

Evidence contract: 1
E2E target: $target
Sandbox required: $sandbox_required
Default-branch constrained: $default_branch_constrained
Reason: $reason
EOF
}

@test "branch E2E accepts reasoned sandbox N/A" {
  write_outcome \
    "PR branch" \
    "no"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "code-or-docs" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"verification evidence is valid"* ]]
}

@test "default-branch-only workflow rejects a branch target" {
  write_outcome \
    "PR branch" \
    "yes" \
    "yes"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "default-branch-only workflow" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"must target sandbox repo or both"* ]]
}

@test "default-branch-only workflow accepts a sandbox target" {
  write_outcome \
    "sandbox repo" \
    "yes" \
    "yes"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "default-branch-only workflow" \
    --verification-target "sandbox repo" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 0 ]
}

@test "default-branch-only workflow rejects a contradictory no constraint" {
  write_outcome \
    "sandbox repo" \
    "yes" \
    "no"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "default-branch-only workflow" \
    --verification-target "sandbox repo" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"requires Default-branch constrained: yes"* ]]
}

@test "supporting checks cannot replace user-outcome evidence" {
  cat >"$TMP_DIR/pr.md" <<'EOF'
## User outcome validation — PRIMARY

**Problem statement tested:** no

**User outcome / 15-minute test performed:** no

**Result:** blocked

## Sandbox dogfood evidence

Evidence contract: 1
E2E target: PR branch
Sandbox required: no
Default-branch constrained: no
Reason: Synthetic PR fixtures do not exercise the user outcome

EOF

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "code-or-docs" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"user-outcome validation is incomplete"* ]]
}

@test "mixed change requires an explicit default-branch constraint" {
  write_outcome \
    "PR branch" \
    "no"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
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
    "yes"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "mixed" \
    --default-branch-constrained "yes" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"default-branch-constrained changes must target sandbox repo or both"* ]]
}

@test "branch-testable mixed change accepts reasoned sandbox N/A" {
  write_outcome \
    "PR branch" \
    "no"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "mixed" \
    --default-branch-constrained "no" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"verification evidence is valid"* ]]
}

@test "default-branch-constrained mixed change accepts a sandbox target" {
  write_outcome \
    "sandbox repo" \
    "yes" \
    "yes"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
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

@test "validator rejects an unsupported evidence contract" {
  write_outcome \
    "PR branch" \
    "no"

  run python3 "$VALIDATOR" \
    --contract-version 2 \
    --change-class "mixed" \
    --default-branch-constrained "no" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported verification evidence contract"* ]]
}

@test "mixed change rejects a mismatched body constraint" {
  write_outcome \
    "PR branch" \
    "no" \
    "yes"

  run python3 "$VALIDATOR" \
    --contract-version 1 \
    --change-class "mixed" \
    --default-branch-constrained "no" \
    --verification-target "PR branch" \
    --pr-body "$TMP_DIR/pr.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Default-branch constrained value does not match"* ]]
}

@test "validator rejects missing placeholder and vague routing reasons" {
  local reason
  for reason in "" "<specific reason>" "representative test constraint"; do
    write_outcome \
      "PR branch" \
      "no" \
      "no" \
      "$reason"

    run python3 "$VALIDATOR" \
      --contract-version 1 \
      --change-class "mixed" \
      --default-branch-constrained "no" \
      --verification-target "PR branch" \
      --pr-body "$TMP_DIR/pr.md"

    [ "$status" -eq 1 ]
    [[ "$output" == *"requires a specific routing reason"* ]]
  done
}
