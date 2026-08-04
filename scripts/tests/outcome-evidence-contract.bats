#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/outcome-evidence-test.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

write_valid_evidence() {
  cat >"$1" <<'JSON'
{
  "claims": [
    {
      "material_claim": "A disposable repository was created.",
      "environment": "fresh derived repository",
      "why_representative": "Repository creation is the user journey.",
      "implementation_sha": "controller:current-head",
      "action_performed": "Ran create-derived-repo.sh --apply.",
      "expected_result": "One private derived repository exists.",
      "observed_result": "The repository exists with template ancestry.",
      "artifact": "https://github.com/example/product",
      "artifact_type": "redacted-api-output",
      "redaction": "Secret values and user identifiers removed.",
      "retention": "PR-lifetime embedded record; external locator is authenticated.",
      "evidence_reuse": "none",
      "result": "pass"
    }
  ]
}
JSON
}

@test "canonical issue plan requires material claim artifacts and provenance" {
  plan="$REPO_ROOT/.github/templates/issue-implementation-plan.md"

  grep -q 'Material claim:' "$plan"
  grep -q 'Environment:' "$plan"
  grep -q 'Why representative:' "$plan"
  grep -q 'Implementation SHA:' "$plan"
  grep -q 'Action performed:' "$plan"
  grep -q 'Expected result:' "$plan"
  grep -q 'Observed result:' "$plan"
  grep -q 'Artifact:' "$plan"
  grep -q 'Artifact type:' "$plan"
  grep -q 'Redaction:' "$plan"
  grep -q 'Retention:' "$plan"
  grep -q 'Evidence reuse:' "$plan"
  grep -q 'Result:' "$plan"
}

@test "PR template uses outcome evidence without universal sandbox links" {
  template="$REPO_ROOT/.github/pull_request_template.md"

  grep -q '^## User outcome evidence$' "$template"
  grep -q 'Material claim:' "$template"
  grep -q 'Environment:' "$template"
  grep -q 'Choose the most representative practical environment' "$template"
  grep -q 'remain blocked until performed' "$template"
  ! grep -q '^## Sandbox dogfood evidence$' "$template"
  ! grep -q '^Sandbox issue:' "$template"
  ! grep -q '^Sandbox PR:' "$template"
}

@test "policy prioritizes representative fidelity over cost" {
  policy="$REPO_ROOT/AGENTS.md"
  guide="$REPO_ROOT/docs/guides/outcome-validation.md"

  grep -q 'most representative practical environment' "$policy"
  grep -q 'Cost, speed, safety, and resource use are constraints' "$policy"
  grep -q 'explicit approval before performing it' "$policy"
  grep -q 'keep the outcome result blocked' "$policy"
  grep -q '^## Preserve the user journey$' "$guide"
  grep -q 'generate, send, deploy, publish, write, or mutate' "$guide"
  grep -q 'among equally representative' "$guide"
  ! grep -q 'is an isolated environment' "$guide"
  grep -q 'Prefer isolation when it does not reduce fidelity' "$guide"
}

@test "standalone plan and ADR select environments by fidelity first" {
  plan="$REPO_ROOT/.github/PLAN_TEMPLATE.md"
  adr="$REPO_ROOT/docs/decisions/adr-034-outcome-equivalent-verification.md"

  grep -q 'most representative' "$plan"
  grep -q 'equally representative options' "$plan"
  grep -q '^### Clarification (2026-07-25)$' "$adr"
  grep -q 'prioritizes evidentiary fidelity' "$adr"
  ! grep -q 'practical isolated' "$adr"
  grep -q 'Isolation is preferred when it does not reduce fidelity' "$adr"
}

@test "outcome evidence validator rejects prose-only external state" {
  write_valid_evidence "$TEST_ROOT/valid.json"
  jq '.claims[0].artifact = "" | .claims[0].artifact_type = ""' \
    "$TEST_ROOT/valid.json" >"$TEST_ROOT/evidence.json"

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/evidence.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"artifact"* ]]
}

@test "outcome evidence validator rejects a prose assertion as an artifact" {
  write_valid_evidence "$TEST_ROOT/evidence.json"
  jq '.claims[0].artifact = "asserted in prose"' \
    "$TEST_ROOT/evidence.json" >"$TEST_ROOT/prose.json"

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/prose.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"artifact must be an HTTPS URL or embedded record locator"* ]]
}

@test "outcome evidence validator rejects inadequate retention metadata" {
  write_valid_evidence "$TEST_ROOT/evidence.json"
  jq '.claims[0].retention = "unknown"' \
    "$TEST_ROOT/evidence.json" >"$TEST_ROOT/retention.json"

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/retention.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"retention"* ]]
}

@test "outcome evidence validator rejects earlier-SHA evidence without reuse analysis" {
  write_valid_evidence "$TEST_ROOT/evidence.json"
  jq '.claims[0].artifact = "embedded:redacted-api-output" | .claims[0].implementation_sha = "0123456"' \
    "$TEST_ROOT/evidence.json" >"$TEST_ROOT/reuse.json"

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/reuse.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"evidence_reuse"* ]]
}

@test "outcome evidence validator rejects vague earlier-SHA reuse prose" {
  write_valid_evidence "$TEST_ROOT/evidence.json"
  jq '.claims[0].artifact = "embedded:redacted-api-output" |
      .claims[0].implementation_sha = "0123456" |
      .claims[0].evidence_reuse = "reviewed"' \
    "$TEST_ROOT/evidence.json" >"$TEST_ROOT/reuse.json"

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/reuse.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Paths: and Conditions:"* ]]
}

@test "outcome evidence validator rejects empty earlier-SHA reuse sections" {
  write_valid_evidence "$TEST_ROOT/evidence.json"
  jq '.claims[0].artifact = "embedded:redacted-api-output" |
      .claims[0].implementation_sha = "0123456" |
      .claims[0].evidence_reuse = "Paths:; Conditions:"' \
    "$TEST_ROOT/evidence.json" >"$TEST_ROOT/reuse.json"

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/reuse.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"non-empty Paths: and Conditions:"* ]]
}

@test "outcome evidence validator accepts earlier-SHA evidence with reuse analysis" {
  write_valid_evidence "$TEST_ROOT/evidence.json"
  jq '.claims[0].artifact = "embedded:redacted-api-output" |
      .claims[0].implementation_sha = "0123456" |
      .claims[0].evidence_reuse = "Paths: evidence text only; Conditions: tested runtime and trigger are unchanged."' \
    "$TEST_ROOT/evidence.json" >"$TEST_ROOT/reuse.json"

  run python3 "$REPO_ROOT/scripts/validate-outcome-evidence.py" "$TEST_ROOT/reuse.json"

  [ "$status" -eq 0 ]
}

@test "outcome evidence validator accepts an auditable material claim" {
  write_valid_evidence "$TEST_ROOT/evidence.json"

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
  [[ "$output" == *"**Environment:** isolated fix worktree"* ]]
  [[ "$output" == *"**Why representative:** The original reproduction command runs here."* ]]
  [[ "$output" == *"**Implementation SHA:**"* ]]
  [[ "$output" == *"**Action performed:** Ran the recorded repro steps."* ]]
  [[ "$output" == *"**Expected result:** The repro exits successfully."* ]]
  [[ "$output" == *"**Observed result:** The repro exits successfully."* ]]
  [[ "$output" == *"**Artifact:** embedded:fix-verification-table"* ]]
  [[ "$output" == *"**Artifact type:** command-transcript"* ]]
  [[ "$output" == *"**Redaction:** No secrets present."* ]]
  [[ "$output" == *"**Retention:** PR lifetime"* ]]
  [[ "$output" == *"**Evidence reuse:** none"* ]]
  [[ "$output" == *"**Result:** pass"* ]]
  [[ "$output" != *"## Sandbox dogfood evidence"* ]]
  [[ "$output" != *"Sandbox issue:"* ]]
  [[ "$output" != *"| sandbox |"* ]]
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
