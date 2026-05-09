#!/usr/bin/env bash
# scripts/checks/020-active-md-schema.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- _active.md multi-task schema (ADR-018) ---
# `_active.md` uses a multi-section schema: each in-flight branch owns one
# `## Task: <branch-name>` section under the `# Active Tasks` header.
# Enforce: (a) the file has the `# Active Tasks` header; (b) the file does
# NOT contain the legacy `# Active Task` (singular) header from the old
# single-task schema — mixed-format files indicate an incomplete migration;
# (c) when the body below the schema comment block is non-empty, at least
# one `## Task:` section header is present. An empty body (template-
# onboarding state) is allowed; a body with task content but no `## Task:`
# header is not.
if [[ -f ".context/state/_active.md" ]]; then
  if grep -qE '^# Active Tasks\b' .context/state/_active.md; then
    pass ".context/state/_active.md has '# Active Tasks' header (ADR-018 schema)"
  else
    fail ".context/state/_active.md missing '# Active Tasks' header (ADR-018 schema)"
  fi

  # Reject the legacy singular-form header — its presence means the ADR-018
  # migration was incomplete (legacy single-task block left in place).
  # Match `# Active Task` only when NOT followed by `s` (so the new
  # `# Active Tasks` plural header does not trip the check).
  if grep -qE '^# Active Task([^s]|$)' .context/state/_active.md; then
    fail ".context/state/_active.md contains legacy '# Active Task' (singular) header — ADR-018 migration incomplete"
  else
    pass ".context/state/_active.md has no legacy '# Active Task' (singular) header"
  fi

  # Strip HTML comment blocks and the file header; if anything non-blank
  # remains, require a `## Task:` section header.
  active_body=$(awk '
    /^<!--/ { in_comment = 1 }
    in_comment {
      if (/-->/) { in_comment = 0 }
      next
    }
    /^# Active Tasks/ { next }
    { print }
  ' .context/state/_active.md | grep -v '^[[:space:]]*$' || true)
  if [[ -z "$active_body" ]]; then
    pass ".context/state/_active.md body is empty (template-onboarding state allowed)"
  elif printf '%s\n' "$active_body" | grep -qE '^## Task:[[:space:]]+\S'; then
    pass ".context/state/_active.md has at least one '## Task: <branch>' section (ADR-018)"
  else
    fail ".context/state/_active.md has body content but no '## Task: <branch>' section (ADR-018 schema)"
  fi
fi

echo ""
