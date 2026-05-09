#!/usr/bin/env bash
# scripts/checks/50-agent-mirror.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Agent Mirror Sanity Checks ---
# The template ships two parallel agent registries so both Copilot's custom-
# agent runtime and Claude Code's native subagent loader dispatch on the same
# 9 roles. Canonical role files live in .github/agents/<role>.agent.md
# (Copilot schema); Claude Code mirrors live in .claude/agents/<role>.md
# (Claude Code schema). See docs/decisions/adr-002-claude-code-subagent-
# registration.md for rationale.
echo "Checking .claude/agents mirror of .github/agents..."

# Check A: every canonical .github/agents/*.agent.md has a matching
# .claude/agents/*.md mirror. This prevents future role additions from
# silently skipping Claude Code registration.
for gh_file in .github/agents/*.agent.md; do
  [[ -f "$gh_file" ]] || continue
  role="$(basename "$gh_file" .agent.md)"
  claude_file=".claude/agents/${role}.md"
  if [[ -f "$claude_file" ]]; then
    pass "$claude_file mirrors $gh_file"
  else
    fail "$claude_file is missing (every .github/agents/<role>.agent.md needs a .claude/agents/<role>.md mirror)"
  fi
done

# Check B: description: frontmatter line must be byte-identical between the
# two copies for every role, so Copilot SDK intent-matching and Claude Code
# auto-dispatch route on the same string. Drift is a hard failure.
for gh_file in .github/agents/*.agent.md; do
  [[ -f "$gh_file" ]] || continue
  role="$(basename "$gh_file" .agent.md)"
  claude_file=".claude/agents/${role}.md"
  [[ -f "$claude_file" ]] || continue # Check A already flagged this
  gh_desc="$(grep -m1 '^description:' "$gh_file" || true)"
  cc_desc="$(grep -m1 '^description:' "$claude_file" || true)"
  if [[ -n "$gh_desc" && "$gh_desc" == "$cc_desc" ]]; then
    pass "$role description: matches between .github and .claude"
  else
    fail "$role description: differs between $gh_file and $claude_file"
  fi
done

# Check C: per-platform model: allowlist (ADR-019, issue #220 Phase 2).
# Per-platform value-space divergence is intentional — Claude Code accepts
# Anthropic-only model strings; Copilot accepts the qualified
# `Model Name (vendor)` format. Description parity (Check B above) is on
# the description: field only and is unaffected.

# C.1 — Claude Code allowlist (.claude/agents/*.md):
#   model: value MUST be one of: inherit, claude-opus-4-7,
#   claude-sonnet-4-6, claude-haiku-4-5.
#   Every file MUST have a model: line (no omission allowed; Low tier
#   uses `model: inherit`).
claude_allowlist_re='^model: (inherit|claude-opus-4-7|claude-sonnet-4-6|claude-haiku-4-5)$'
for cc_file in .claude/agents/*.md; do
  [[ -f "$cc_file" ]] || continue
  role="$(basename "$cc_file" .md)"
  cc_model="$(grep -m1 '^model:' "$cc_file" || true)"
  if [[ -z "$cc_model" ]]; then
    fail "$role .claude/agents/$role.md missing model: line (ADR-019 requires explicit pin or 'model: inherit')"
  elif [[ "$cc_model" =~ $claude_allowlist_re ]]; then
    pass "$role Claude model: line matches allowlist ($cc_model)"
  else
    fail "$role Claude model: line not in ADR-019 allowlist: $cc_model (allowed: inherit, claude-opus-4-7, claude-sonnet-4-6, claude-haiku-4-5)"
  fi
done

# C.2 — Copilot allowlist (.github/agents/*.agent.md):
#   model: line is EITHER absent (Low tier; inherits main session)
#   OR matches the qualified-format regex
#   ^model: '<Name> (copilot)'$ where <Name> uses the printable subset
#   [A-Za-z0-9. ()-]. v1 ships single-string pins only; native YAML
#   array fallback (per ADR-019 Amendment #2) is documented as
#   follow-up and is NOT yet accepted by this regex.
copilot_allowlist_re="^model: '[A-Za-z0-9. ()-]+ \\(copilot\\)'$"
for gh_file in .github/agents/*.agent.md; do
  [[ -f "$gh_file" ]] || continue
  role="$(basename "$gh_file" .agent.md)"
  gh_model="$(grep -m1 '^model:' "$gh_file" || true)"
  if [[ -z "$gh_model" ]]; then
    pass "$role Copilot model: line absent (Low tier; inherits main session)"
  elif [[ "$gh_model" =~ $copilot_allowlist_re ]]; then
    pass "$role Copilot model: line matches qualified-format allowlist ($gh_model)"
  else
    fail "$role Copilot model: line not in ADR-019 allowlist: $gh_model (expected ^model: '<Model Name> (copilot)'$ or omitted)"
  fi
done

echo ""
