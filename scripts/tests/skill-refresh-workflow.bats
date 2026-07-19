#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCANNER="$REPO_ROOT/scripts/scan-skill-secrets.py"
  WORKFLOW="$REPO_ROOT/.github/workflows/skill-refresh.yml"
  FIXTURE_ROOT="$BATS_TEST_TMPDIR/secret-fixtures"
  mkdir -p "$FIXTURE_ROOT"
}

@test "skill secret scan rejects credential signatures with locations" {
  cat >"$FIXTURE_ROOT/leaked.md" <<'EOF'
access_key = AKIAIOSFODNN7EXAMPLE
-----BEGIN PRIVATE KEY-----
EOF

  run python3 "$SCANNER" "$FIXTURE_ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"leaked.md:1: aws-access-key-id"* ]]
  [[ "$output" == *"leaked.md:2: private-key"* ]]
}

@test "skill secret scan accepts documented placeholders" {
  cat >"$FIXTURE_ROOT/placeholders.md" <<'EOF'
api_key = "${RENDER_API_KEY}"
password = "replace-with-your-password"
token = "<your-token>"
EOF

  run python3 "$SCANNER" "$FIXTURE_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"findings": 0'* ]]
}

@test "nightly refresh workflow is source-scoped and review-first" {
  [ -f "$WORKFLOW" ]
  run grep -q 'cron: "0 5 \* \* \*"' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'workflow_dispatch:' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'contents: write' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'pull-requests: write' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'matrix.source' "$WORKFLOW"
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  run grep -Fq 'group: skill-refresh-${{ matrix.source }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  run grep -Fq 'branch: automation/skill-refresh/${{ matrix.source }}' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Fq 'uses: peter-evans/create-pull-request@5f6978faf089d4d20b00c7766989d076bb2fc7f1' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'draft: always' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'delete-branch: false' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q "if: steps.check.outputs.changed == 'true'" "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'scan-skill-secrets.py' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q 'validate-lock' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -q './test.sh' "$WORKFLOW"
  [ "$status" -eq 0 ]
  run grep -Eiq 'enable-auto-merge|merge-method:|auto-merge:' "$WORKFLOW"
  [ "$status" -eq 1 ]
}
