#!/usr/bin/env bats
#
# scripts/tests/verify-env.bats
#
# Inlined from scripts/test-verify-env.sh by issue #280 (un-wrap legacy delegate).
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
  # ===== inlined body of scripts/test-verify-env.sh (issue #280) =====
# Unit tests for scripts/verify-env.sh (issue #229 Phase 1.5a).
#
# Tests the TEMPLATE_PLACEHOLDER detection logic in verify-env.sh using
# isolated fixture directories (minimal git repos). Covers the four
# failure-mode classes identified from PR #228 R5/R7/R8:
#
#   FIXTURE-01  empty        — no TEMPLATE_PLACEHOLDER files → clean pass
#   FIXTURE-02  bootstrap    — only bootstrap-state files contain the marker
#                              (excluded by _PLACEHOLDER_EXCLUDE) → state-
#                              files warning, no unexpected-files warning
#   FIXTURE-03  overlap      — filename that shares a common prefix with an
#                              excluded path but does NOT match the anchored
#                              ($) pattern (e.g. coordination.md.bak). Tests
#                              that the regex anchor prevents false exclusion.
#   FIXTURE-04  mixed        — unexpected file + bootstrap file → both
#                              warning classes fire independently
#
# Why these matter: The regex logic in verify-env.sh uses `$`-anchored
# alternatives in _PLACEHOLDER_EXCLUDE and _PLACEHOLDER_LEGIT. A missing
# anchor (the PR #228 R7→R8 lesson) would cause FIXTURE-03 to wrong-classify
# 'coordination.md.bak' as an excluded file, making the test fail.
#
# Run: bash scripts/test-verify-env.sh


VERIFY_SCRIPT="$REPO_ROOT/scripts/verify-env.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

# ── helpers ──────────────────────────────────────────────────────────────────

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected to contain: %s\n' "$needle"
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if ! printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected NOT to contain: %s\n' "$needle"
  fi
}

# Run verify-env.sh inside a temp fixture dir, return its stdout.
# Exit code is ignored (it exits non-zero in a bare temp dir due to missing
# files; we only care about the placeholder-section output).
run_in_fixture() {
  local fixture_dir="$1"
  cd "$fixture_dir" && bash "$VERIFY_SCRIPT" 2>/dev/null || true
}

# ── setup ─────────────────────────────────────────────────────────────────────

TMP_BASE=$(mktemp -d)
# shellcheck disable=SC2317  # invoked via trap
cleanup() { rm -rf "$TMP_BASE"; }
trap cleanup EXIT

marker="TEMPLATE_PLACEHOLDER"

make_fixture() {
  local name="$1"
  local dir="$TMP_BASE/$name"
  mkdir -p "$dir"
  # Must be a git repo so verify-env.sh's git checks pass
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "test"
  printf '%s' "$dir"
}

echo "========================================"
echo "verify-env.sh fixture tests (issue #229 §1.5a)"
echo "========================================"
echo ""

# ── FIXTURE-01: empty ─────────────────────────────────────────────────────────
echo "FIXTURE-01: empty tree"
D=$(make_fixture "empty")
out=$(run_in_fixture "$D")
assert_contains "empty: pass message present" \
  "No unexpected TEMPLATE_PLACEHOLDER markers found" "$out"
assert_not_contains "empty: no unexpected-file warning" \
  "files still contain TEMPLATE_PLACEHOLDER" "$out"
assert_not_contains "empty: no bootstrap warning" \
  "Bootstrap state files retain" "$out"
echo ""

# ── FIXTURE-02: bootstrap-only ────────────────────────────────────────────────
echo "FIXTURE-02: only bootstrap-state files contain marker"
D=$(make_fixture "bootstrap")
mkdir -p "$D/.context/state" "$D/.context/sessions"
printf '%s\n' "# $marker" >"$D/.context/state/_active.md"
printf '%s\n' "# $marker" >"$D/.context/sessions/latest_summary.md"
out=$(run_in_fixture "$D")
assert_contains "bootstrap: pass message (excluded don't count)" \
  "No unexpected TEMPLATE_PLACEHOLDER markers found" "$out"
assert_not_contains "bootstrap: no unexpected-file warning" \
  "files still contain TEMPLATE_PLACEHOLDER" "$out"
assert_contains "bootstrap: bootstrap warning fires" \
  "Bootstrap state files retain TEMPLATE_PLACEHOLDER" "$out"
echo ""

# ── FIXTURE-03: substring-overlap filename ────────────────────────────────────
echo "FIXTURE-03: substring-overlap filename tests \$-anchor"
D=$(make_fixture "overlap")
mkdir -p "$D/.context/state"
# coordination.md matches _PLACEHOLDER_EXCLUDE → excluded (state file)
printf '%s\n' "# $marker" >"$D/.context/state/coordination.md"
# coordination.md.bak does NOT match the anchored pattern → unexpected
printf '%s\n' "# $marker" >"$D/.context/state/coordination.md.bak"
out=$(run_in_fixture "$D")
assert_not_contains "overlap: clean pass (unexpected file exists)" \
  "No unexpected TEMPLATE_PLACEHOLDER markers found" "$out"
assert_contains "overlap: unexpected-file warning (coordination.md.bak not excluded)" \
  "files still contain TEMPLATE_PLACEHOLDER" "$out"
assert_contains "overlap: bootstrap warning fires for coordination.md" \
  "Bootstrap state files retain TEMPLATE_PLACEHOLDER" "$out"
echo ""

# ── FIXTURE-04: mixed ─────────────────────────────────────────────────────────
echo "FIXTURE-04: mixed — unexpected file + bootstrap file"
D=$(make_fixture "mixed")
mkdir -p "$D/.context/state" "$D/.context/sessions"
# Bootstrap (excluded → does NOT count as unexpected)
printf '%s\n' "# $marker" >"$D/.context/state/_active.md"
# Unexpected (not matched by either exclusion list)
printf '%s\n' "# $marker" >"$D/some-real-file.md"
out=$(run_in_fixture "$D")
assert_not_contains "mixed: no clean pass (unexpected file exists)" \
  "No unexpected TEMPLATE_PLACEHOLDER markers found" "$out"
assert_contains "mixed: unexpected-file warning" \
  "files still contain TEMPLATE_PLACEHOLDER" "$out"
assert_contains "mixed: bootstrap warning also fires" \
  "Bootstrap state files retain TEMPLATE_PLACEHOLDER" "$out"
echo ""

# ── summary ──────────────────────────────────────────────────────────────────

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

@test "verify-env: inlined test-verify-env.sh body passes" {
  run _legacy_body
  if [ "$status" -ne 0 ]; then
    printf 'STATUS=%s\nOUTPUT:\n%s\n' "$status" "$output" >&2
  fi
  [ "$status" -eq 0 ]
}
