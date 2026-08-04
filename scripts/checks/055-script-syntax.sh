#!/usr/bin/env bash
# scripts/checks/055-script-syntax.sh — extracted from test.sh by issue #255 Phase 4d;
# expanded by issue #281 to cover every .sh file in the repo (was only
# install.sh + test.sh). Sourced by test.sh; relies on $PASS/$FAIL/$WARN,
# pass()/fail()/warn() from scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Script Syntax Check ---
# Rationale: a bash syntax error is the cheapest possible regression to
# catch (`bash -n`, no execution, sub-second). Pre-#281 the check
# covered only install.sh and test.sh, leaving 50+ other .sh files
# (scripts/, scripts/checks/, scripts/lib/, scripts/setup/) un-gated.
# Any of those could ship with a syntax error and only blow up at
# runtime in CI or for a downstream contributor.
echo "Checking script syntax..."

# Enable nullglob *before* the array assignment so unmatched patterns
# vanish during expansion (bash expands globs at assignment time, not
# at loop-iteration time — see test.sh ~L54 for the same pattern).
shopt -s nullglob

# Glob set: every authored .sh under the repo. The patterns are listed
# explicitly (rather than `find . -name '*.sh'`) so generated/vendored
# trees and node_modules-style directories can never sneak into the
# check, and so adding a new top-level shell directory requires a
# deliberate entry here. Repository-authored skill roots are added from
# skills-lock.json ownedSkills; externally locked skill packages remain excluded.
# scripts/tests/*.bats is intentionally
# excluded — bats files are not valid bash and should be exercised
# via `bats`, not `bash -n` (see scripts/checks/070-*.sh ff.).
SYNTAX_CHECK_GLOBS=(
  ./*.sh
  scripts/*.sh
  scripts/checks/*.sh
  scripts/lib/*.sh
  scripts/setup/*.sh
)

if [[ -f skills-lock.json ]] && command -v jq >/dev/null 2>&1; then
  while IFS= read -r skill_root; do
    [[ -d "$skill_root" ]] || continue
    while IFS= read -r -d '' skill_script; do
      SYNTAX_CHECK_GLOBS+=("$skill_script")
    done < <(find "$skill_root" -type f -name '*.sh' -print0 | sort -z)
  done < <(jq -r '.ownedSkills[]?.destinationPath // empty' skills-lock.json)
else
  fail "skills-lock.json and jq are required to discover repository-authored skill scripts"
fi

shopt -u nullglob

for f in "${SYNTAX_CHECK_GLOBS[@]}"; do
  # Defensive guard: if a pattern was a literal filename that doesn't
  # exist (or a stray symlink to a directory), skip rather than letting
  # bash -n surface a confusing error.
  [[ -f "$f" ]] || continue
  if bash -n "$f"; then
    pass "$f has valid bash syntax"
  else
    fail "$f has syntax errors"
  fi
done

echo ""
