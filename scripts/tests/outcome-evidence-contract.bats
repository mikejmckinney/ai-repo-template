#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/outcome-evidence-test.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "canonical issue plan requires material claim artifacts and provenance" {
  plan="$REPO_ROOT/.github/templates/issue-implementation-plan.md"

  grep -q 'Material claim:' "$plan"
  grep -q 'Why representative:' "$plan"
  grep -q 'Implementation SHA:' "$plan"
  grep -q 'Artifact:' "$plan"
  grep -q 'Redaction:' "$plan"
  grep -q 'Retention:' "$plan"
  grep -q 'Evidence reuse:' "$plan"
}

@test "PR template uses outcome evidence without universal sandbox links" {
  template="$REPO_ROOT/.github/pull_request_template.md"

  grep -q '^## User outcome evidence$' "$template"
  grep -q 'Material claim:' "$template"
  grep -q 'Environment:' "$template"
  ! grep -q '^## Sandbox dogfood evidence$' "$template"
  ! grep -q '^Sandbox issue:' "$template"
  ! grep -q '^Sandbox PR:' "$template"
}

@test "outcome evidence validator rejects prose-only external state" {
  cat >"$TEST_ROOT/evidence.json" <<'JSON'
{
  "claims": [
    {
      "material_claim": "A disposable repository was created.",
      "environment": "fresh derived repository",
      "why_representative": "Repository creation is the user journey.",
      "implementation_sha": "0123456789abcdef0123456789abcdef01234567",
      "action_performed": "Ran create-derived-repo.sh --apply.",
      "expected_result": "One private derived repository exists.",
      "observed_result": "The repository exists.",
      "artifact": "",
      "artifact_type": "",
      "redaction": "No credential values retained.",
      "retention": "PR lifetime",
      "evidence_reuse": "none",
      "result": "pass"
    }
  ]
}
JSON

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/evidence.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"artifact"* ]]
}

@test "outcome evidence validator accepts an auditable material claim" {
  cat >"$TEST_ROOT/evidence.json" <<'JSON'
{
  "claims": [
    {
      "material_claim": "A disposable repository was created.",
      "environment": "fresh derived repository",
      "why_representative": "Repository creation is the user journey.",
      "implementation_sha": "0123456789abcdef0123456789abcdef01234567",
      "action_performed": "Ran create-derived-repo.sh --apply.",
      "expected_result": "One private derived repository exists.",
      "observed_result": "The repository exists with template ancestry.",
      "artifact": "https://github.com/example/product",
      "artifact_type": "redacted-api-output",
      "redaction": "Secret values and user identifiers removed.",
      "retention": "Embedded PR record; external locator is authenticated.",
      "evidence_reuse": "none",
      "result": "pass"
    }
  ]
}
JSON

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/evidence.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1 material claim"* ]]
}

@test "fix PR renderer emits outcome evidence instead of universal sandbox labels" {
  cat >"$TEST_ROOT/fix-verify.json" <<'JSON'
{
  "findings": [
    {
      "dedupe_key": "key-a",
      "verify": {
        "pre": "reproduced",
        "post": "fixed",
        "sandbox": "n/a",
        "notes": "Verified after implementation."
      }
    }
  ],
  "outcome_evidence": {
    "claims": [
      {
        "material_claim": "The reported defect no longer reproduces.",
        "environment": "isolated fix worktree",
        "why_representative": "The original reproduction command runs here.",
        "implementation_sha": "0123456789abcdef0123456789abcdef01234567",
        "action_performed": "Ran the recorded repro steps.",
        "expected_result": "The repro exits successfully.",
        "observed_result": "The repro exits successfully.",
        "artifact": "embedded:fix-verification-table",
        "artifact_type": "command-transcript",
        "redaction": "No secrets present.",
        "retention": "PR lifetime",
        "evidence_reuse": "none",
        "result": "pass"
      }
    ]
  }
}
JSON

  run python3 "$REPO_ROOT/scripts/workflows/lib/render-fix-pr-sections.py" \
    "$TEST_ROOT/fix-verify.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *"## User outcome evidence"* ]]
  [[ "$output" == *"The reported defect no longer reproduces."* ]]
  [[ "$output" != *"## Sandbox dogfood evidence"* ]]
  [[ "$output" != *"Sandbox issue:"* ]]
}

@test "verification classifier points to environment selection and specialized adapter" {
  script="$REPO_ROOT/scripts/verify-pr.sh"

  grep -q 'docs/guides/outcome-validation.md' "$script"
  grep -q 'docs/guides/sandbox-verification.md' "$script"
  ! grep -q 'Verification target: sandbox repo (or both)' "$script"
}

@test "new ADR partially supersedes universal ADR-029 evidence rules" {
  adr="$REPO_ROOT/docs/decisions/adr-034-outcome-equivalent-verification.md"

  grep -q '^# ADR-034:' "$adr"
  grep -q 'partially supersedes ADR-029' "$adr"
  grep -q 'ADR-016 remains active' "$adr"
  grep -q 'material claim' "$adr"
  grep -q 'PR lifetime' "$adr"
}
