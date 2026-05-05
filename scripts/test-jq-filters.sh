#!/usr/bin/env bash
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
# Run: bash scripts/test-jq-filters.sh

set -euo pipefail

# Guard: jq must be installed — tests cannot run without it and a silent
# 0-assertion pass (PASS=0, FAIL=0) is not a useful result.
if ! command -v jq &>/dev/null; then
  printf '  ❌ jq not installed — cannot run filter tests\n'
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JQ_DIR="$REPO_ROOT/scripts/lib/jq"
FIXTURE_DIR="$JQ_DIR/fixtures"

PASS=0
FAIL=0
FAILED_NAMES=()

assert_filter() {
  local name="$1" filter="$2" input_file="$3" expected_file="$4"
  local actual expected
  actual=$(jq -rf "$filter" "$input_file" 2>/dev/null || printf 'JQ_ERROR')
  expected=$(cat "$expected_file")
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected: %s\n' "$expected"
    printf '       actual:   %s\n' "$actual"
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
