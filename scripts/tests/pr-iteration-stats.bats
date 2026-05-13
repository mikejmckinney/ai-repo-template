#!/usr/bin/env bats
#
# scripts/tests/pr-iteration-stats.bats
#
# Inlined from scripts/test-pr-iteration-stats.sh by issue #280 (un-wrap legacy delegate).
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
  # ===== inlined body of scripts/test-pr-iteration-stats.sh (issue #280) =====
# Unit tests for scripts/pr-iteration-stats.sh (issue #229 Phase 1).
#
# Tests the Python parsing logic in isolation by invoking parser.py
# directly with fixture JSON, avoiding the need for a live `gh` session
# or GitHub API access.
#
# Run: bats --tap scripts/tests/pr-iteration-stats.bats



# Guard: python3 is required for fixture building and parsing.
if ! command -v python3 &>/dev/null; then
  printf 'Error: python3 is not installed or not in PATH.\n' >&2
  exit 1
fi

PASS=0
FAIL=0
FAILED_NAMES=()

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf '  ✅ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  ❌ %s\n' "$name"
    printf '       expected: %q\n' "$expected"
    printf '       actual:   %q\n' "$actual"
  fi
}

# ---------------------------------------------------------------------------
# Set up temp dir with parser.py (extracted from pr-iteration-stats.sh)
# ---------------------------------------------------------------------------
TMP_DIR=$(mktemp -d)
# shellcheck disable=SC2317  # invoked via trap
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Extract parser.py from pr-iteration-stats.sh so tests always exercise the
# actual implementation — no manual copy required (ISS-OTKN).
awk 'p&&/^PYEOF$/{p=0;next} /parser\.py.*<<.PYEOF./{p=1;next} p' \
  "$REPO_ROOT/scripts/pr-iteration-stats.sh" >"$TMP_DIR/parser.py"
if [[ ! -s "$TMP_DIR/parser.py" ]]; then
  printf 'Error: failed to extract parser.py from pr-iteration-stats.sh\n' >&2
  exit 1
fi

# fixture_builder.py — builds fixture JSON by scenario name, avoids shell
# escaping issues with multi-line bodies embedded in JSON strings.
cat >"$TMP_DIR/fixture_builder.py" <<'PYEOF'
import sys, json

REPORT_FIX = (
    "## Resolution Report \u2014 Round 3\n\n"
    "Fixed in this pass: 2\nTotal items found: 3\n"
)
REPORT_FIX_CANONICAL = (
    "## Resolution Report\n\n"
    "Fixed in this pass: 1\nTotal items found: 2\n"
)
REPORT_FIX_BOLD = (
    "## Resolution Report\n\n"
    "- **Total items found**: 3\n"
    "- **Already resolved**: 0\n"
    "- **Fixed in this pass**: 2\n"
    "- **Needs clarification**: 1\n"
)
REPORT_REJECTED = (
    "## Resolution Report \u2014 Round 5\n\n"
    "Fixed in this pass: 0\nTotal items found: 2\n"
)
REPORT_NO_ITEMS = (
    "## Resolution Report \u2014 Round 1\n\n"
    "Fixed in this pass: 0\nTotal items found: 0\n"
)
REGULAR = "Just a normal review comment, no report header."

def make_pr(number, threads_total, threads_resolved, comments):
    nodes = [{"isResolved": i < threads_resolved}
             for i in range(threads_total)]
    return {
        "number": number,
        "reviewThreads": {"totalCount": threads_total, "nodes": nodes},
        "comments": {"nodes": comments},
    }

def bot(login, body):
    return {"body": body, "author": {"login": login}}

def human(body):
    return {"body": body, "author": {"login": "mikejmckinney"}}

FIXTURES = {
    "one_fix": [make_pr(101, 2, 1, [
        bot("claude[bot]", REPORT_FIX),
    ])],
    "canonical_fix": [make_pr(107, 1, 1, [
        bot("claude[bot]", REPORT_FIX_CANONICAL),
    ])],
    "bold_fix": [make_pr(108, 2, 2, [
        bot("copilot-pull-request-reviewer[bot]", REPORT_FIX_BOLD),
    ])],
    "one_rejected": [make_pr(102, 3, 0, [
        bot("copilot-pull-request-reviewer[bot]", REPORT_REJECTED),
    ])],
    "mixed": [make_pr(103, 4, 2, [
        bot("claude[bot]", REPORT_FIX),
        bot("copilot-pull-request-reviewer[bot]", REPORT_REJECTED),
        bot("gemini-code-assist[bot]", REPORT_NO_ITEMS),
    ])],
    "human_only": [make_pr(104, 0, 0, [
        human(REGULAR),
    ])],
    "empty_prs": [],
    "no_comments": [make_pr(105, 0, 0, [])],
    "body_only_detection": [make_pr(106, 1, 1, [
        {"body": REPORT_FIX, "author": {"login": "unknown-user"}},
    ])],
    # 150 threads (120 resolved) + 1 fix comment: verifies parser handles
    # arrays larger than the old first-100 cap without undercounting.
    "large_threads": [make_pr(109, 150, 120, [
        bot("copilot-pull-request-reviewer[bot]", REPORT_FIX),
    ])],
}

print(json.dumps(FIXTURES[sys.argv[1]]))
PYEOF

# Helpers
make_fixture() { python3 "$TMP_DIR/fixture_builder.py" "$1"; }
parse_pr_json() { python3 "$TMP_DIR/parser.py"; }
field() {
  local key="$1" idx="${2:-0}"
  python3 -c "import sys,json; r=json.load(sys.stdin)[$idx]; print(r['$key'])"
}

# ---------------------------------------------------------------------------
# Test suite
# ---------------------------------------------------------------------------
echo "pr-iteration-stats parser tests"
echo ""

# ── Test 1: One fix round ───────────────────────────────────────────────────
echo "total_rounds / fix_rounds"

result=$(make_fixture one_fix | parse_pr_json)
assert_eq "one fix comment → total_rounds=1" "1" "$(printf '%s' "$result" | field total_rounds)"
assert_eq "one fix comment → fix_rounds=1" "1" "$(printf '%s' "$result" | field fix_rounds)"
assert_eq "one fix comment → rejected_rounds=0" "0" "$(printf '%s' "$result" | field rejected_rounds)"
echo ""

# ── Test 2: One all-rejected round ─────────────────────────────────────────
echo "rejected_rounds counter"

result=$(make_fixture one_rejected | parse_pr_json)
assert_eq "one rejected comment → total_rounds=1" "1" "$(printf '%s' "$result" | field total_rounds)"
assert_eq "one rejected comment → fix_rounds=0" "0" "$(printf '%s' "$result" | field fix_rounds)"
assert_eq "one rejected comment → rejected_rounds=1" "1" "$(printf '%s' "$result" | field rejected_rounds)"
echo ""

# ── Test 3: Mixed rounds ────────────────────────────────────────────────────
echo "mixed rounds (fix + rejected + no-items)"

result=$(make_fixture mixed | parse_pr_json)
assert_eq "mixed PR → total_rounds=3" "3" "$(printf '%s' "$result" | field total_rounds)"
assert_eq "mixed PR → fix_rounds=1" "1" "$(printf '%s' "$result" | field fix_rounds)"
assert_eq "mixed PR → rejected_rounds=1" "1" "$(printf '%s' "$result" | field rejected_rounds)"
assert_eq "mixed PR → threads_opened=4" "4" "$(printf '%s' "$result" | field threads_opened)"
assert_eq "mixed PR → threads_resolved=2" "2" "$(printf '%s' "$result" | field threads_resolved)"
echo ""

# ── Test 4: Non-agent comment not counted ──────────────────────────────────
echo "non-agent comments excluded"

result=$(make_fixture human_only | parse_pr_json)
assert_eq "human comment → total_rounds=0" "0" "$(printf '%s' "$result" | field total_rounds)"
echo ""

# ── Test 5: Empty PR list ───────────────────────────────────────────────────
echo "empty PR list"

result=$(make_fixture empty_prs | parse_pr_json)
count=$(printf '%s' "$result" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')
assert_eq "empty input → empty results" "0" "$count"
echo ""

# ── Test 6: PR with zero comments ──────────────────────────────────────────
echo "PR with zero comments"

result=$(make_fixture no_comments | parse_pr_json)
assert_eq "no comments → total_rounds=0" "0" "$(printf '%s' "$result" | field total_rounds)"
echo ""

# ── Test 7: Body-only detection (unrecognised login) ────────────────────────
echo "body-only detection fallback"

result=$(make_fixture body_only_detection | parse_pr_json)
assert_eq "body-only detection → total_rounds=1" "1" "$(printf '%s' "$result" | field total_rounds)"
echo ""

# ── Test 8: --help exits 0 and mentions key flags ───────────────────────────
echo "CLI --help flag"

help_exit=0
help_out=$(bash "$REPO_ROOT/scripts/pr-iteration-stats.sh" --help 2>&1) || help_exit=$?
assert_eq "--help exits 0" "0" "$help_exit"
if printf '%s' "$help_out" | grep -qF -- '--window'; then
  PASS=$((PASS + 1))
  printf '  ✅ --help mentions --window\n'
else
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("--help mentions --window")
  printf '  ❌ --help does not mention --window\n'
fi
if printf '%s' "$help_out" | grep -qF -- '--json'; then
  PASS=$((PASS + 1))
  printf '  ✅ --help mentions --json\n'
else
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("--help mentions --json")
  printf '  ❌ --help does not mention --json\n'
fi
echo ""

# ── Test 9: Unknown flag exits non-zero ─────────────────────────────────────
echo "CLI unknown flag"

bad_exit=0
bash "$REPO_ROOT/scripts/pr-iteration-stats.sh" --not-a-flag 2>/dev/null || bad_exit=$?
if [[ "$bad_exit" -ne 0 ]]; then
  PASS=$((PASS + 1))
  printf '  ✅ unknown flag exits non-zero (%d)\n' "$bad_exit"
else
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("unknown flag exits non-zero")
  printf '  ❌ unknown flag should exit non-zero\n'
fi
echo ""

# ── Test 10: Canonical header (## Resolution Report, no round suffix) ────────
echo "canonical header (no '— Round N' suffix)"

result=$(make_fixture canonical_fix | parse_pr_json)
assert_eq "canonical header → total_rounds=1" "1" "$(printf '%s' "$result" | field total_rounds)"
assert_eq "canonical header → fix_rounds=1" "1" "$(printf '%s' "$result" | field fix_rounds)"
echo ""

# ── Test 11: Markdown-bold counter labels (- **Fixed in this pass**: X) ──────
echo "markdown-bold counter labels (canonical pr-resolve-all.md format)"

result=$(make_fixture bold_fix | parse_pr_json)
assert_eq "bold labels → total_rounds=1" "1" "$(printf '%s' "$result" | field total_rounds)"
assert_eq "bold labels → fix_rounds=1" "1" "$(printf '%s' "$result" | field fix_rounds)"
assert_eq "bold labels → rejected_rounds=0" "0" "$(printf '%s' "$result" | field rejected_rounds)"
echo ""

# ── Test 12: Threads array larger than the old first-100 cap ─────────────────
echo "large thread array (150 threads, 120 resolved)"

result=$(make_fixture large_threads | parse_pr_json)
assert_eq "large threads → threads_opened=150" "150" "$(printf '%s' "$result" | field threads_opened)"
assert_eq "large threads → threads_resolved=120" "120" "$(printf '%s' "$result" | field threads_resolved)"
assert_eq "large threads → total_rounds=1" "1" "$(printf '%s' "$result" | field total_rounds)"
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "─────────────────────────────────────"
echo "Passed: $PASS"
echo "Failed: $FAIL"
if ((FAIL > 0)); then
  echo ""
  echo "Failed tests:"
  for n in "${FAILED_NAMES[@]}"; do echo "  - $n"; done
  exit 1
fi
exit 0
  # ===== end inlined body =====
}

@test "pr-iteration-stats: inlined test-pr-iteration-stats.sh body passes" {
  run _legacy_body
  # Emit captured output as TAP `# ...` comments so the
  # per-assertion ✅/PASS [...] markers from the inlined
  # legacy body remain visible (and grep-able by
  # run_bats_check) even on the success path. (#280 round 3)
  printf '%s
' "$output" | sed 's/^/# /' >&3 || true
  [ "$status" -eq 0 ]
}
