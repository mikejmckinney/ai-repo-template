#!/usr/bin/env bash
# scripts/checks/050-agent-mirror.sh — rewritten by issue #248 to canonical-as-reference
# N-way parity (was 2-way github↔claude before). Sourced by test.sh; relies on
# $PASS/$FAIL/$WARN, pass()/fail()/warn() from scripts/lib/{logging,assertions}.sh
# and CWD == repo root.

# --- Canonical/Overlay Parity Checks (ADR-023) ---
# Role responsibilities live exactly once at .agents/<role>.md (canonical,
# platform-agnostic). Each registered platform has a thin overlay folder
# carrying only platform-specific frontmatter (name casing, tools vocabulary,
# model pin) plus a one-line pointer back to canonical. This file enforces:
#
#   1. Every canonical .agents/<role>.md has a matching overlay in every
#      registered platform folder (no role silently skipped on any platform).
#   2. Every overlay's `description:` frontmatter line is byte-identical to
#      canonical's (Copilot SDK and Claude Code intent-matching dispatch on
#      the same string).
#   3. Every overlay's `model:` line matches that platform's ADR-019
#      allowlist.
#   4. Every overlay body contains a string reference to .agents/<role>.md
#      (catches accidental shim regression where someone re-paraphrases
#      role responsibilities into the overlay).
#
# Adding a new platform = add one entry to the `platforms` array below and
# one allowlist regex constant. No per-role logic to add.
echo "Checking canonical/overlay parity (.agents/ ↔ .github/agents/, .claude/agents/)..."

# Per-platform configuration via parallel arrays (a packed-string row layout
# would split the model regexes on their alternation `|` chars when read with
# `IFS='|' read`). To add a new platform, append one element to each array
# AT THE SAME INDEX.
copilot_allowlist_re="^model: '[A-Za-z0-9. ()-]+ \\(copilot\\)'$"
claude_allowlist_re='^model: (inherit|claude-opus-4-7|claude-sonnet-4-6|claude-haiku-4-5)$'

platforms=(           "copilot"          "claude"        )
overlay_dirs=(        ".github/agents"   ".claude/agents")
overlay_suffixes=(    ".agent.md"        ".md"           )
model_allowlist_res=( "$copilot_allowlist_re" "$claude_allowlist_re" )
# model_required: 1 = must have a model: line; 0 = may omit (Copilot Low tier
# inherits main session per ADR-019).
model_required_flags=("0"                "1"             )

# Iterate every canonical role. Each canonical file is the source of truth for
# the description: line and the role name; overlays must mirror.
for canonical in .agents/*.md; do
  [[ -f "$canonical" ]] || continue
  base="$(basename "$canonical" .md)"
  # Skip the README; canonical role files are <role>.md but not README.md.
  [[ "$base" == "README" ]] && continue
  role="$base"

  canonical_desc="$(grep -m1 '^description:' "$canonical" || true)"
  if [[ -z "$canonical_desc" ]]; then
    fail "$role canonical .agents/$role.md missing description: frontmatter line"
    continue
  fi

  for i in "${!platforms[@]}"; do
    platform="${platforms[$i]}"
    overlay_dir="${overlay_dirs[$i]}"
    overlay_suffix="${overlay_suffixes[$i]}"
    model_re="${model_allowlist_res[$i]}"
    model_required="${model_required_flags[$i]}"
    overlay="${overlay_dir}/${role}${overlay_suffix}"

    # Check 1: overlay exists.
    if [[ ! -f "$overlay" ]]; then
      fail "$role $platform overlay missing: expected $overlay (every .agents/<role>.md needs a $platform overlay)"
      continue
    fi
    pass "$role $platform overlay present at $overlay"

    # Check 2: description: line matches canonical byte-for-byte.
    overlay_desc="$(grep -m1 '^description:' "$overlay" || true)"
    if [[ -n "$overlay_desc" && "$overlay_desc" == "$canonical_desc" ]]; then
      pass "$role $platform description: matches canonical"
    else
      fail "$role $platform description: differs from canonical (.agents/$role.md)"
    fi

    # Check 3: model: line matches platform allowlist.
    overlay_model="$(grep -m1 '^model:' "$overlay" || true)"
    if [[ -z "$overlay_model" ]]; then
      if [[ "$model_required" == "1" ]]; then
        fail "$role $platform overlay missing model: line (ADR-019 requires explicit pin or 'model: inherit' for this platform)"
      else
        pass "$role $platform model: line absent (Low tier; inherits main session)"
      fi
    elif [[ "$overlay_model" =~ $model_re ]]; then
      pass "$role $platform model: line matches allowlist ($overlay_model)"
    else
      fail "$role $platform model: line not in ADR-019 allowlist: $overlay_model"
    fi

    # Check 4: overlay body references canonical (catches shim regression where
    # someone paraphrases role responsibilities back into the overlay). The
    # check is intentionally a substring match against the canonical pointer
    # path — any link, code-fenced reference, or prose mention satisfies it.
    if grep -q ".agents/${role}.md" "$overlay"; then
      pass "$role $platform overlay body references canonical .agents/$role.md"
    else
      fail "$role $platform overlay body must reference .agents/$role.md (overlays are pointers; do not paraphrase canonical responsibilities)"
    fi
  done
done

echo ""
#!/usr/bin/env bash
# scripts/checks/050-agent-mirror.sh — extracted from test.sh by issue #255 Phase 4d.
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
