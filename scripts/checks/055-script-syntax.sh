#!/usr/bin/env bash
# scripts/checks/055-script-syntax.sh — extracted from test.sh by issue #255 Phase 4d;
# expanded by issue #281 to cover every .sh file in the repo (was only
# install.sh + test.sh). Sourced by test.sh; relies on $PASS/$FAIL/$WARN,
# pass()/fail()/warn() from scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Script Syntax Check ---
# Rationale: a bash syntax error is the cheapest possible regression to
# catch (`bash -n`, no execution, sub-second). Pre-#281 the check
# covered only install.sh and test.sh, leaving 51 other .sh files
# (scripts/, scripts/checks/, scripts/lib/, scripts/setup/) un-gated.
# Any of those could ship with a syntax error and only blow up at
# runtime in CI or for a downstream contributor.
echo "Checking script syntax..."

# Glob set: every authored .sh under the repo. The patterns are listed
# explicitly (rather than `find . -name '*.sh'`) so generated/vendored
# trees and node_modules-style directories can never sneak into the
# check, and so adding a new top-level shell directory requires a
# deliberate entry here.
SYNTAX_CHECK_GLOBS=(
  ./*.sh
  scripts/*.sh
  scripts/checks/*.sh
  scripts/lib/*.sh
  scripts/setup/*.sh
)

shopt -s nullglob
for f in "${SYNTAX_CHECK_GLOBS[@]}"; do
  # Skip if glob expanded to a non-file (defensive — nullglob already
  # drops unmatched patterns, but keep the guard so a stray symlink to
  # a directory doesn't surface as a confusing bash -n failure).
  [[ -f "$f" ]] || continue
  if bash -n "$f" 2>/dev/null; then
    pass "$f has valid bash syntax"
  else
    fail "$f has syntax errors"
  fi
done
shopt -u nullglob

echo ""
#!/usr/bin/env bash
# scripts/checks/055-script-syntax.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Script Syntax Check ---
echo "Checking script syntax..."

if bash -n install.sh 2>/dev/null; then
  pass "install.sh has valid bash syntax"
else
  fail "install.sh has syntax errors"
fi

if bash -n test.sh 2>/dev/null; then
  pass "test.sh has valid bash syntax"
else
  fail "test.sh has syntax errors"
fi

echo ""
