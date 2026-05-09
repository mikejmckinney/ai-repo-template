#!/usr/bin/env bats
#
# scripts/tests/jq-filters.bats
#
# Inlined from scripts/test-jq-filters.sh by issue #280 (un-wrap legacy delegate).
# The legacy script's body lives as the shell function `_legacy_body`
# inside this file; the @test block invokes it via bats `run` so bats'
# subshell wrapping preserves set -e + EXIT-trap semantics. No external
# scripts/test-*.sh delegate file remains.

# Per-test timeout (seconds). Must be set at file-load time, before any
# test runs (codex/cursor P2 review feedback on PR #274).
export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
}

_legacy_body() {
  set -euo pipefail
  cd "$REPO_ROOT"
  SCRIPT_DIR="$REPO_ROOT/scripts"
  # ===== inlined body of scripts/test-jq-filters.sh (issue #280) =====
# Unit tests for jq filters in scripts/lib/jq/ (issue #229 Phase 1.5b).
#
# For each <name>.jq file, finds matching fixture pairs:
#   scripts/lib/jq/fixtures/<name>-<tag>.in.json
#   scripts/lib/jq/fixtures/<name>-<tag>.out
# Runs jq -rf <filter> against each .in.json and compares output to .out
# (string equality; trailing-newline differences are normalised by jq).
#
# Purpose: catch semantic jq bugs (operator-precedence, incorrect filters)
# before they surface in PR review — the class of bug that drove PR #225's
# 11 rounds (jq `a, b | f` vs `[a] + [b]` precedence).
#
# Run: bats --tap scripts/tests/jq-filters.bats


# Guard: jq must be installed — tests cannot run without it and a silent
# 0-assertion pass (PASS=0, FAIL=0) is not a useful result.
if ! command -v jq &>/dev/null; then
  printf '  ❌ jq not installed — cannot run filter tests\n'
  exit 1
fi

JQ_DIR="$REPO_ROOT/scripts/lib/jq"
FIXTURE_DIR="$JQ_DIR/fixtures"

PASS=0
FAIL=0
FAILED_NAMES=()
# sHfu: single shared error log, cleaned by trap on exit/interrupt
ERR_LOG=$(mktemp "${TMPDIR:-/tmp}/jq-test-err.XXXXXX")
# shellcheck disable=SC2317  # invoked via trap
cleanup_err_log() { rm -f "$ERR_LOG"; }
trap cleanup_err_log EXIT

assert_filter() {
  local name="$1" filter="$2" input_file="$3" expected_file="$4"
  local actual expected
  if ! actual=$(jq -rf -- "$filter" "$input_file" 2>"$ERR_LOG"); then
    actual='JQ_ERROR'
  fi
  expected=$(cat -- "$expected_file")
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected: %s\n' "$expected"
    printf '       actual:   %s\n' "$actual"
    if [[ -s "$ERR_LOG" ]]; then
      printf '       error:    %s\n' "$(cat "$ERR_LOG")"
    fi
  fi
}

echo "========================================"
echo "jq filter unit tests (issue #229 §1.5b)"
echo "========================================"
echo ""

# Guard: jq_dir must exist
if [[ ! -d "$JQ_DIR" ]]; then
  printf '  ❌ scripts/lib/jq/ directory missing\n'
  exit 1
fi

# Discover filters and run matching fixtures
found_any=0
for filter_file in "$JQ_DIR"/*.jq; do
  [[ -f "$filter_file" ]] || continue
  filter_name="$(basename "$filter_file" .jq)"
  found_any=1

  echo "Filter: $filter_name"

  # Find fixture pairs for this filter
  fixture_found=0
  for in_file in "$FIXTURE_DIR/${filter_name}"-*.in.json; do
    [[ -f "$in_file" ]] || continue
    tag="${in_file#"$FIXTURE_DIR/${filter_name}-"}"
    tag="${tag%.in.json}"
    out_file="$FIXTURE_DIR/${filter_name}-${tag}.out"
    if [[ ! -f "$out_file" ]]; then
      printf '  ⚠️  %s-%s — SKIP (missing .out file: %s)\n' "$filter_name" "$tag" "$out_file"
      continue
    fi
    fixture_found=1
    assert_filter "${filter_name}:${tag}" "$filter_file" "$in_file" "$out_file"
  done

  if [[ "$fixture_found" -eq 0 ]]; then
    printf '  ⚠️  no fixture pairs found for %s (expected %s/<filter>-<tag>.in.json)\n' \
      "$filter_name" "$FIXTURE_DIR"
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$filter_name:no-fixtures")
  fi
  echo ""
done

if [[ "$found_any" -eq 0 ]]; then
  printf '  ⚠️  no .jq files found in %s\n' "$JQ_DIR"
fi

echo "========================================"
echo "Results"
echo "========================================"
printf 'Passed: %d\n' "$PASS"
printf 'Failed: %d\n' "$FAIL"

if [[ "${#FAILED_NAMES[@]}" -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for n in "${FAILED_NAMES[@]}"; do
    printf '  - %s\n' "$n"
  done
fi

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
  # ===== end inlined body =====
}

@test "jq-filters: inlined test-jq-filters.sh body passes" {
  run _legacy_body
  # Emit captured output as TAP `# ...` comments so the
  # per-assertion ✅/PASS [...] markers from the inlined
  # legacy body remain visible (and grep-able by
  # run_bats_check) even on the success path. (#280 round 3)
  printf '%s
' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
}
