#!/usr/bin/env bash
# scripts/checks/025-sessions-hygiene.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- sessions/ hygiene (canonical template + rotation rule + size cap + freshness) ---
# Enforces the working-log discipline added by the cadence-trigger rewrite:
# `latest_summary.md` carries one entry per agent-session updated continuously
# at every wait-for-input pause, with rotation to date-stamped archives when a
# new agent starts. Size and freshness checks emit warnings (not failures) so
# downstream forks aren't blocked on cadence drift; the structural template
# checks (a) are hard fails because they protect the rule's contract.
echo "Checking sessions/ hygiene..."

# (a) sessions/README.md must define the canonical Working-Log Template with required fields.
if [[ -f ".context/sessions/README.md" ]]; then
  if grep -qE '^## Working-Log Template' .context/sessions/README.md; then
    pass ".context/sessions/README.md has '## Working-Log Template' header"
  else
    fail ".context/sessions/README.md missing '## Working-Log Template' header"
  fi

  # Required template fields. The template fields appear inside a fenced code
  # block in sessions/README.md; grep -F finds them whether or not they are
  # the file's actual headers. Includes both `**bold**` field markers (Status,
  # Issue/PR, Started — required at session start) and `## headers` (filled
  # progressively across the session) so the template enforcement is complete
  # rather than only header-deep. Scoped to the §"Working-Log Template"
  # section via awk-bounded extraction (per Gemini review on PR #261, test.sh:222)
  # so the same field names appearing elsewhere in the README cannot satisfy
  # the assertion incidentally.
  working_log_template_section=$(awk '/^## Working-Log Template/,/^## Why This Matters/' .context/sessions/README.md)
  for field in "**Status**" "**Issue/PR**" "**Started**" "## What Was Accomplished" "## What Shipped" "## Harder Than Expected" "## Generalizable Lessons" "## Files Modified" "## Open Items / Next"; do
    if echo "$working_log_template_section" | grep -qF "$field"; then
      pass ".context/sessions/README.md template defines field: $field"
    else
      fail ".context/sessions/README.md template missing required field: $field"
    fi
  done

  # Rotation rule must be documented (per AGENTS.md cadence and the README §"Rotation rule" subsection).
  if grep -qE '^### Rotation rule' .context/sessions/README.md; then
    pass ".context/sessions/README.md documents rotation rule (§'Rotation rule')"
  else
    fail ".context/sessions/README.md missing '### Rotation rule' subsection"
  fi
fi

# (b) latest_summary.md size cap — warn at >100 lines per Token Efficiency rule.
if [[ -f ".context/sessions/latest_summary.md" ]]; then
  ls_lines=$(wc -l <.context/sessions/latest_summary.md)
  if [[ "$ls_lines" -le 100 ]]; then
    pass "latest_summary.md is within size cap ($ls_lines lines, cap 100)"
  else
    warn "latest_summary.md exceeds size cap ($ls_lines lines, cap 100) — rotate to a date-stamped archive (see sessions/README.md §'Rotation rule')"
  fi
fi

# (c) latest_summary.md freshness — warn if the most recent '# Session: YYYY-MM-DD'
# header is > 7 days old. Uses GNU date for offset arithmetic; skips silently
# on BSD date (macOS) where `date -d` is unsupported.
if [[ -f ".context/sessions/latest_summary.md" ]] && command -v date >/dev/null 2>&1; then
  latest_date=$(grep -E '^# Session: [0-9]{4}-[0-9]{2}-[0-9]{2}' .context/sessions/latest_summary.md | cut -d' ' -f3 | sort -r | head -1)
  if [[ -n "$latest_date" ]]; then
    if today_epoch=$(date -u +%s 2>/dev/null) \
      && entry_epoch=$(date -u -d "$latest_date" +%s 2>/dev/null); then
      age_days=$(((today_epoch - entry_epoch) / 86400))
      if [[ "$age_days" -le 7 ]]; then
        pass "latest_summary.md most recent entry is fresh ($age_days days old)"
      else
        warn "latest_summary.md most recent entry is $age_days days old (threshold 7) — consider rotating per sessions/README.md §'Rotation rule'"
      fi
    fi
  fi
fi

echo ""
