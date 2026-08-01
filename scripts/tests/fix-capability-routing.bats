#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fix-capability-routing.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

write_batch() {
  cat >"$TEST_ROOT/batch.json" <<'JSON'
{
  "run_date": "2026-08-01",
  "findings": [
    {
      "category": "follow_up_issues",
      "priority_band": "fix-now",
      "dedupe_key": "worktree-finding",
      "verification_capability": {
        "environment": "isolated-worktree",
        "harness_id": "repository-test-suite",
        "reason": "The repository test suite reproduces the defect."
      }
    },
    {
      "category": "follow_up_issues",
      "priority_band": "fix-now",
      "dedupe_key": "codespaces-finding",
      "verification_capability": {
        "environment": "codespaces",
        "harness_id": null,
        "reason": "The reproduction requires a private Codespace and secret mutation."
      }
    },
    {
      "category": "follow_up_issues",
      "priority_band": "should-fix",
      "dedupe_key": "missing-capability"
    }
  ]
}
JSON
}

prepare_cascade_repo() {
  CASCADE_REPO="$TEST_ROOT/repo"
  mkdir -p "$CASCADE_REPO" "$TEST_ROOT/bin"
  git -C "$CASCADE_REPO" init -q
  git -C "$CASCADE_REPO" config user.email test@example.com
  git -C "$CASCADE_REPO" config user.name Test
  printf 'base\n' >"$CASCADE_REPO/result.txt"
  git -C "$CASCADE_REPO" add result.txt
  git -C "$CASCADE_REPO" commit -qm base
  printf 'fix this\n' >"$TEST_ROOT/prompt.md"
  write_batch
  cat >"$TEST_ROOT/bin/python3" <<'EOF'
#!/usr/bin/env bash
case "${1##*/}" in
  validate-fix-verification.py|validate-outcome-evidence.py) exit 0 ;;
  *) exec /usr/bin/python3 "$@" ;;
esac
EOF
  chmod +x "$TEST_ROOT/bin/python3"
}

@test "fix routing selects only allowlisted repository-owned capabilities" {
  write_batch

  run python3 "$REPO_ROOT/scripts/workflows/lib/route-fixable-findings.py" \
    "$TEST_ROOT/batch.json" "$TEST_ROOT/routed.json"

  [ "$status" -eq 0 ]
  run jq -e '
    [.findings[].dedupe_key] == ["worktree-finding"] and
    [.deferred_findings[].dedupe_key] == ["codespaces-finding", "missing-capability"] and
    (.deferred_findings[0].routing_reason | contains("codespaces")) and
    (.deferred_findings[1].routing_reason | contains("missing"))
  ' "$TEST_ROOT/routed.json"
  [ "$status" -eq 0 ]
}

@test "controller rebuilds finding identities and owns execution fields" {
  write_batch
  verify="$TEST_ROOT/fix-verify.json"

  run python3 "$REPO_ROOT/scripts/workflows/lib/manage-fix-verification.py" prepare \
    "$TEST_ROOT/batch.json" "$verify"
  [ "$status" -eq 0 ]
  jq '.findings = [{
    dedupe_key: "worktree-finding",
    implementation_reasoning: "Changed the failing branch.",
    proposed_harness_id: "repository-test-suite",
    controller_execution: {status: "passed", candidate_exit_code: 99}
  }]' "$verify" >"$TEST_ROOT/provider.json"
  mv "$TEST_ROOT/provider.json" "$verify"

  run python3 "$REPO_ROOT/scripts/workflows/lib/manage-fix-verification.py" finalize \
    "$TEST_ROOT/batch.json" "$verify" --provider opencode \
    --requested-model test-model --baseline-exit-code 1 --candidate-exit-code 0

  [ "$status" -eq 0 ]
  run jq -e '
    [.findings[].dedupe_key] == ["worktree-finding", "codespaces-finding", "missing-capability"] and
    .findings[0].implementation_reasoning == "Changed the failing branch." and
    .findings[0].controller_execution == {
      harness_id: "repository-test-suite",
      baseline_exit_code: 1,
      candidate_exit_code: 0,
      status: "passed"
    } and
    .controller.provider == "opencode" and
    .controller.requested_model == "test-model"
  ' "$verify"
  [ "$status" -eq 0 ]
}

@test "failed attempts retain bounded redacted controller diagnostics" {
  prepare_cascade_repo
  diagnostics="$TEST_ROOT/diagnostics"

  run env PATH="$TEST_ROOT/bin:$PATH" FIX_PROVIDER_DIAGNOSTICS_DIR="$diagnostics" \
    POSTMERGE_RETRO_MODEL=test-model bash -c '
      list_advisory_providers() { printf "%s\n" opencode; }
      invoke_advisory_llm() {
        printf "candidate\n" >result.txt
        printf "token=super-secret-value\n" >&2
        return 7
      }
      apply_noop() { return 0; }
      source "$1"
      FIX_PROVIDER_BASELINE_VERIFY_COMMAND=true FIX_PROVIDER_VERIFY_COMMAND=true \
        run_fix_provider_cascade retro-fix "$2" "$3" "$4" "$4" "$5" "$6" \
          apply_noop "$7" retro/fix-verify-test.json
    ' _ "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
    "$TEST_ROOT/prompt.md" "$TEST_ROOT/output.txt" "$CASCADE_REPO" "$TEST_ROOT" \
    "$REPO_ROOT/scripts/workflows/lib" "$TEST_ROOT/batch.json"

  [ "$status" -ne 0 ]
  [ "$(find "$diagnostics" -type f -name '*.json' | wc -l | tr -d ' ')" -eq 1 ]
  diagnostic="$(find "$diagnostics" -type f -name '*.json')"
  run jq -e '
    .provider == "opencode" and .requested_model == "test-model" and
    .failed_stage == "provider invocation" and .exit_status == 7 and
    (.changed_paths | index("result.txt")) and
    (.excerpt | length <= 2000)
  ' "$diagnostic"
  [ "$status" -eq 0 ]
  run grep -F 'super-secret-value' "$diagnostic"
  [ "$status" -ne 0 ]
}

@test "Gemini retries one malformed response with bounded parse diagnostics" {
  prepare_cascade_repo

  run env PATH="$TEST_ROOT/bin:$PATH" INVOCATIONS="$TEST_ROOT/invocations" \
    RETRY_PROMPT="$TEST_ROOT/retry-prompt" bash -c '
      list_advisory_providers() { printf "%s\n" gemini; }
      invoke_advisory_llm() {
        count=0
        [[ -f "$INVOCATIONS" ]] && count="$(cat "$INVOCATIONS")"
        count=$((count + 1))
        printf "%s\n" "$count" >"$INVOCATIONS"
        if ((count == 2)); then
          cp "$1" "$RETRY_PROMPT"
        fi
        printf "response-%s\n" "$count" >"$2"
      }
      apply_gemini() {
        if [[ "$(cat "$INVOCATIONS")" -eq 1 ]]; then
          printf "No JSON object found in LLM output\n" >"$FIX_PROVIDER_GEMINI_ERROR_FILE"
          return 1
        fi
        printf "gemini-fixed\n" >result.txt
      }
      source "$1"
      FIX_PROVIDER_BASELINE_VERIFY_COMMAND=true FIX_PROVIDER_VERIFY_COMMAND=true \
        run_fix_provider_cascade retro-fix "$2" "$3" "$4" "$4" "$5" "$6" \
          apply_gemini "$7" retro/fix-verify-test.json
    ' _ "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
    "$TEST_ROOT/prompt.md" "$TEST_ROOT/output.txt" "$CASCADE_REPO" "$TEST_ROOT" \
    "$REPO_ROOT/scripts/workflows/lib" "$TEST_ROOT/batch.json"

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/invocations")" -eq 2 ]
  grep -q 'No JSON object found' "$TEST_ROOT/retry-prompt"
  grep -q 'valid JSON only' "$TEST_ROOT/retry-prompt"
  [ "$(cat "$CASCADE_REPO/result.txt")" = gemini-fixed ]
}

@test "daily and weekly fix jobs always upload failed-attempt diagnostics" {
  run python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
for relative in (
    ".github/workflows/agent-postmerge-retro.yml",
    ".github/workflows/agent-weekly-review.yml",
):
    text = (root / relative).read_text(encoding="utf-8")
    assert "Upload failed fix-attempt diagnostics" in text, relative
    section = text.split("- name: Upload failed fix-attempt diagnostics", 1)[1]
    assert "if: always()" in section[:200], relative
    assert ".artifacts/fix-provider-diagnostics/" in section[:600], relative
PY

  [ "$status" -eq 0 ]
}

@test "fix prompts delegate execution to repository-owned controller harnesses" {
  for prompt in post-merge-retro-fix.md weekly-repo-review-fix.md; do
    run grep -F 'Do not execute `repro_steps`' "$REPO_ROOT/.github/prompts/$prompt"
    [ "$status" -eq 0 ]
    run grep -F 'implementation_reasoning' "$REPO_ROOT/.github/prompts/$prompt"
    [ "$status" -eq 0 ]
    run grep -F 'proposed_harness_id' "$REPO_ROOT/.github/prompts/$prompt"
    [ "$status" -eq 0 ]
  done
}
