#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ci-failure-report-test.XXXXXX")"
  printf 'bats failed: expected true\n' >"$TEST_ROOT/bats.log"
  printf 'repository checks failed: missing file\n' >"$TEST_ROOT/tests.log"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "Bats-only failure report includes only the failed Bats output" {
  run env CI_WORKFLOW='CI Tests' CI_RUN_NUMBER=7 CI_RUN_URL=https://example.test/runs/7 \
    CI_BRANCH=feature/test CI_COMMIT=abc123 CI_RETRY_COUNT=1 CI_MAX_RETRIES=3 \
    "$REPO_ROOT/scripts/render-ci-failure-report.sh" "$TEST_ROOT/report.md" failure success \
    "$TEST_ROOT/bats.log" "$TEST_ROOT/tests.log"

  [ "$status" -eq 0 ]
  grep -q '### Bats Failure Output' "$TEST_ROOT/report.md"
  grep -q 'bats failed: expected true' "$TEST_ROOT/report.md"
  ! grep -q 'repository checks failed' "$TEST_ROOT/report.md"
}

@test "repository-check-only failure report includes its failed output" {
  run env CI_WORKFLOW='CI Tests' CI_RUN_NUMBER=7 CI_RUN_URL=https://example.test/runs/7 \
    CI_BRANCH=feature/test CI_COMMIT=abc123 CI_RETRY_COUNT=1 CI_MAX_RETRIES=3 \
    "$REPO_ROOT/scripts/render-ci-failure-report.sh" "$TEST_ROOT/report.md" success failure \
    "$TEST_ROOT/bats.log" "$TEST_ROOT/tests.log"

  [ "$status" -eq 0 ]
  grep -q '### Repository Check Failure Output' "$TEST_ROOT/report.md"
  grep -q 'repository checks failed: missing file' "$TEST_ROOT/report.md"
  ! grep -q 'bats failed' "$TEST_ROOT/report.md"
}

@test "combined failure report retains both bounded sections" {
  python3 - "$TEST_ROOT/bats.log" "$TEST_ROOT/tests.log" <<'PY'
import sys
from pathlib import Path

for path, prefix, marker in (
    (sys.argv[1], "bats", "BATS_TAIL_MARKER"),
    (sys.argv[2], "checks", "CHECKS_TAIL_MARKER"),
):
    lines = [f"{prefix} diagnostic {i:04d} {'x' * 40}" for i in range(3000)]
    lines.append(marker)
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
  run env CI_WORKFLOW='CI Tests' CI_RUN_NUMBER=7 CI_RUN_URL=https://example.test/runs/7 \
    CI_BRANCH=feature/test CI_COMMIT=abc123 CI_RETRY_COUNT=1 CI_MAX_RETRIES=3 \
    "$REPO_ROOT/scripts/render-ci-failure-report.sh" "$TEST_ROOT/report.md" failure failure \
    "$TEST_ROOT/bats.log" "$TEST_ROOT/tests.log"

  [ "$status" -eq 0 ]
  grep -q '### Bats Failure Output' "$TEST_ROOT/report.md"
  grep -q '### Repository Check Failure Output' "$TEST_ROOT/report.md"
  grep -q 'BATS_TAIL_MARKER' "$TEST_ROOT/report.md"
  grep -q 'CHECKS_TAIL_MARKER' "$TEST_ROOT/report.md"
  [ "$(wc -c <"$TEST_ROOT/report.md")" -lt 50000 ]
}
