#!/usr/bin/env bash
# scripts/closeout.sh — deterministic close-out enforcement (issue #262).
#
# Refuses to commit when the close-out artifacts required by the cadence
# rule (`.context/rules/process_session_state.md`) are not in place.
#
# Failure mode shifts from "I'll write the summary later" (silent) to
# "the script refused my commit because I didn't move my lock" (loud).
#
# Six checks (in order):
#   1. State files touched in the working tree (sessions/ + state/).
#   2. Lock for the current branch is no longer in `## Active Locks`.
#   3. `## Task: <branch>` section is removed from `_active.md`.
#   4. Matching `# Session: ... — <branch>` entry in `latest_summary.md`
#      has `Status: done`.
#   5. Rotation hygiene (soft warning only — file > 100 lines OR most
#      recent dated entry > 7 days old).
#   6. Required template headers present in `latest_summary.md`.
#
# Usage:
#   make closeout                  # canonical entry point
#   bash scripts/closeout.sh       # equivalent
#   CLOSEOUT_REPO_ROOT=<path> bash scripts/closeout.sh   # for fixture tests
#
# Exit codes:
#   0  all checks passed; staged + templated commit message printed
#   1  one or more hard-fail checks refused (no staging performed)
#   2  invocation error (no git, not in a git repo, etc.)

set -uo pipefail

REPO_ROOT="${CLOSEOUT_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
if [[ -z "$REPO_ROOT" ]] || [[ ! -d "$REPO_ROOT/.git" && -z "${CLOSEOUT_REPO_ROOT:-}" ]]; then
  printf '✗ closeout: not inside a git repository\n' >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

# Colors (disabled when not a tty)
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'
  NC=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

REFUSE=0
WARN=0

pass() { printf '%s✓%s %s\n' "$GREEN" "$NC" "$1"; }
fail() { printf '%s✗%s %s\n' "$RED" "$NC" "$1" >&2; REFUSE=1; }
warn() { printf '%s⚠%s %s\n' "$YELLOW" "$NC" "$1"; WARN=$((WARN + 1)); }
info() { printf '%s•%s %s\n' "$BLUE" "$NC" "$1"; }

# Paths (constants)
SESSIONS_LATEST=".context/sessions/latest_summary.md"
STATE_ACTIVE=".context/state/_active.md"
STATE_COORD=".context/state/coordination.md"

# Determine the current branch. CLOSEOUT_BRANCH overrides for fixture tests.
BRANCH="${CLOSEOUT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)}"
if [[ -z "$BRANCH" || "$BRANCH" == "HEAD" ]]; then
  fail "could not determine current branch (detached HEAD?)"
  exit 1
fi

printf 'closeout: enforcing cadence discipline for branch %s%s%s\n\n' "$BLUE" "$BRANCH" "$NC"

# ── Check 1: state files touched ────────────────────────────────────────
# Working-tree diff (staged + unstaged) must include latest_summary.md AND
# at least one of _active.md / coordination.md.
changed=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null)

if printf '%s\n' "$changed" | grep -qxF "$SESSIONS_LATEST"; then
  pass "check 1a: $SESSIONS_LATEST touched"
else
  fail "check 1a: close-out commit must touch $SESSIONS_LATEST"
fi

if printf '%s\n' "$changed" | grep -qxF "$STATE_ACTIVE" \
   || printf '%s\n' "$changed" | grep -qxF "$STATE_COORD"; then
  pass "check 1b: $STATE_ACTIVE or $STATE_COORD touched"
else
  fail "check 1b: close-out commit must touch $STATE_ACTIVE or $STATE_COORD"
fi

# ── Check 2: lock moved out of Active Locks ─────────────────────────────
# Extract the body between `## Active Locks` and the next top-level `##`.
# If the branch name appears anywhere in that body (typically as
# `**Session**: <branch>`), the lock has not been moved.
if [[ -f "$STATE_COORD" ]]; then
  # Capture everything between `## Active Locks` and the next non-`## Lock:`
  # `## ` heading (typically `## Recent History`) or EOF. Sub-`## Lock: …`
  # headings are part of the block, not terminators.
  active_locks_body=$(awk '
    /^## Active Locks[[:space:]]*$/ { in_block = 1; next }
    in_block && /^## / && !/^## Lock:/ { in_block = 0 }
    in_block { print }
  ' "$STATE_COORD")
  if printf '%s\n' "$active_locks_body" | grep -qF "$BRANCH"; then
    fail "check 2: lock for branch '$BRANCH' is still in '## Active Locks' — move it to '## Recent History' first"
  else
    pass "check 2: no Active Locks reference branch '$BRANCH'"
  fi
else
  fail "check 2: $STATE_COORD missing"
fi

# ── Check 3: Task section removed from _active.md ───────────────────────
if [[ -f "$STATE_ACTIVE" ]]; then
  if grep -qE "^## Task:[[:space:]]+${BRANCH//\//\\/}([[:space:]]|$)" "$STATE_ACTIVE"; then
    fail "check 3: '## Task: $BRANCH' section still present in $STATE_ACTIVE — remove it"
  else
    pass "check 3: no '## Task: $BRANCH' section in $STATE_ACTIVE"
  fi
else
  fail "check 3: $STATE_ACTIVE missing"
fi

# ── Check 4: Status: done in latest_summary entry ───────────────────────
# Find the `# Session: ... — <branch> — ...` header and look at its
# `**Status**:` field. The match is fuzzy on the separator (em-dash or
# regular hyphen) because both have appeared in real entries.
if [[ -f "$SESSIONS_LATEST" ]]; then
  # Extract the block that starts at the matching session header up to the
  # next `# Session:` header (or EOF).
  session_block=$(awk -v branch="$BRANCH" '
    /^# Session: / {
      if (in_block) { exit }
      if (index($0, branch) > 0) { in_block = 1 }
    }
    in_block { print }
  ' "$SESSIONS_LATEST")

  if [[ -z "$session_block" ]]; then
    fail "check 4: no '# Session: ... $BRANCH ...' entry found in $SESSIONS_LATEST"
  else
    status_line=$(printf '%s\n' "$session_block" | grep -m1 -E '^\*\*Status\*\*:' || true)
    if [[ -z "$status_line" ]]; then
      fail "check 4: matching session entry has no '**Status**:' field"
    elif printf '%s\n' "$status_line" | grep -qE '^\*\*Status\*\*:[[:space:]]*done\b'; then
      pass "check 4: session entry Status is 'done'"
    else
      fail "check 4: session entry Status is not 'done' (found: ${status_line#**Status**: })"
    fi
  fi
else
  fail "check 4: $SESSIONS_LATEST missing"
fi

# ── Check 5: rotation hygiene (soft warning) ────────────────────────────
if [[ -f "$SESSIONS_LATEST" ]]; then
  ls_lines=$(wc -l <"$SESSIONS_LATEST" | tr -d ' ')
  if [[ "$ls_lines" -gt 100 ]]; then
    warn "check 5a: $SESSIONS_LATEST is $ls_lines lines (cap 100) — consider rotating per .context/sessions/README.md §'Rotation rule'"
  else
    pass "check 5a: $SESSIONS_LATEST within size cap ($ls_lines lines)"
  fi

  if command -v date >/dev/null 2>&1; then
    oldest_date=$(grep -E '^# Session: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$SESSIONS_LATEST" \
      | awk '{print $3}' | sort | head -1 || true)
    if [[ -n "$oldest_date" ]]; then
      if today_epoch=$(date -u +%s 2>/dev/null) \
        && entry_epoch=$(date -u -d "$oldest_date" +%s 2>/dev/null); then
        age_days=$(( (today_epoch - entry_epoch) / 86400 ))
        if [[ "$age_days" -gt 7 ]]; then
          warn "check 5b: oldest entry in $SESSIONS_LATEST is $age_days days old (threshold 7) — consider rotating"
        else
          pass "check 5b: oldest entry is $age_days days old (within threshold)"
        fi
      fi
    fi
  fi
fi

# ── Check 6: required template headers in latest_summary.md ─────────────
# These mirror the Working-Log Template fields enforced by test.sh against
# .context/sessions/README.md. We require them in the per-session entries
# of the actual working-log file as well.
if [[ -f "$SESSIONS_LATEST" ]]; then
  REQUIRED_HEADERS=(
    "## What Was Accomplished"
    "## What Shipped"
    "## Harder Than Expected"
    "## Generalizable Lessons"
    "## Files Modified"
    "## Open Items / Next"
  )
  missing_headers=()
  for h in "${REQUIRED_HEADERS[@]}"; do
    if ! grep -qF "$h" "$SESSIONS_LATEST"; then
      missing_headers+=("$h")
    fi
  done
  if [[ ${#missing_headers[@]} -eq 0 ]]; then
    pass "check 6: all required template headers present"
  else
    fail "check 6: $SESSIONS_LATEST missing required headers: ${missing_headers[*]}"
  fi
fi

printf '\n'

# ── Refusal gate ────────────────────────────────────────────────────────
if [[ "$REFUSE" -eq 1 ]]; then
  printf '%sRefusing close-out commit.%s Fix the failures above and re-run %smake closeout%s.\n' \
    "$RED" "$NC" "$BLUE" "$NC" >&2
  exit 1
fi

# ── Stage and offer commit ──────────────────────────────────────────────
to_stage=()
for f in "$SESSIONS_LATEST" "$STATE_ACTIVE" "$STATE_COORD"; do
  if printf '%s\n' "$changed" | grep -qxF "$f"; then
    to_stage+=("$f")
  fi
done

if [[ ${#to_stage[@]} -gt 0 ]]; then
  if [[ -z "${CLOSEOUT_REPO_ROOT:-}" ]]; then
    git add -- "${to_stage[@]}"
    info "staged: ${to_stage[*]}"
  else
    info "would stage (CLOSEOUT_REPO_ROOT set, skipping git add): ${to_stage[*]}"
  fi
fi

cat <<EOF

${GREEN}All checks passed.${NC} Suggested commit:

  git commit -m "chore(closeout): $BRANCH — release lock + finalize working log"

EOF

if [[ "$WARN" -gt 0 ]]; then
  printf '%s%d soft warning(s) above — non-blocking.%s\n' "$YELLOW" "$WARN" "$NC"
fi

exit 0
