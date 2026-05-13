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
copilot_allowlist_re='^model: '\''[A-Za-z0-9. ()-]+ \(copilot\)'\''[[:space:]]*$'
claude_allowlist_re='^model: (inherit|claude-opus-4-7|claude-sonnet-4-6|claude-haiku-4-5)$'

platforms=("copilot" "claude")
overlay_dirs=(".github/agents" ".claude/agents")
overlay_suffixes=(".agent.md" ".md")
model_allowlist_res=("$copilot_allowlist_re" "$claude_allowlist_re")
# model_required: 1 = must have a model: line; 0 = may omit (Copilot Low tier
# inherits main session per ADR-019).
model_required_flags=("0" "1")

# Iterate every canonical role. Each canonical file is the source of truth for
# the description: line and the role name; overlays must mirror.
for canonical in .agents/*.md; do
  [[ -f "$canonical" ]] || continue
  base="$(basename "$canonical" .md)"
  # Skip documentation/template files; canonical role files are <role>.md but
  # not README.md or the ADR-026 role-contract template.
  [[ "$base" == "README" || "$base" == "_TEMPLATE" ]] && continue
  # Skip consensus-candidate-* dry-run scaffolding (issue #295). These are
  # Copilot-only model-pinned dispatch targets used by
  # .github/prompts/multi-model-consensus-plan.md, not first-class roles.
  # They live under .github/agents/ only and are intentionally not mirrored
  # to .agents/ or .claude/agents/. Promote to N-way mirroring once the
  # repo gains a third platform whose models differ meaningfully from
  # Copilot's catalog (e.g., Cursor agent files).
  [[ "$base" == consensus-candidate-* ]] && continue
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
    # `-F` forces literal matching so `.` is not treated as a regex wildcard
    # (otherwise paths like `xagents/<role>Xmd` would falsely satisfy the check).
    #
    # Heuristic limitation: this is intentionally a presence check, not a
    # structural parse. We do not validate that the reference is a real
    # markdown link or that the path resolves on disk; that would require a
    # markdown parser and a path resolver and would be overkill for catching
    # the failure mode this check exists to prevent (a contributor pasting
    # role text back into an overlay shim). False positives are bounded —
    # any literal occurrence of `.agents/<role>.md` anywhere in the overlay
    # passes, which is the correct intent for an "overlays must point at
    # canonical" invariant. See ADR-023 for the canonical/overlay contract.
    if grep -qF ".agents/${role}.md" "$overlay"; then
      pass "$role $platform overlay body references canonical .agents/$role.md"
    else
      fail "$role $platform overlay $overlay body must reference .agents/$role.md (overlays are pointers; do not paraphrase canonical responsibilities)"
    fi
  done
done

echo ""
echo "Checking reverse parity (every overlay has a canonical .agents/<role>.md)..."

# Reverse direction of the loop above: catches stale overlays that survive
# after a canonical role file is deleted/renamed. Without this, `test.sh` would
# only flag the missing direction (canonical → overlay) and orphan overlays
# could ship undetected.
for i in "${!platforms[@]}"; do
  platform="${platforms[$i]}"
  overlay_dir="${overlay_dirs[$i]}"
  overlay_suffix="${overlay_suffixes[$i]}"
  for overlay in "$overlay_dir"/*"$overlay_suffix"; do
    [[ -f "$overlay" ]] || continue
    base="$(basename "$overlay" "$overlay_suffix")"
    [[ "$base" == "README" ]] && continue
    # Skip consensus-candidate-* dry-run scaffolding (issue #295). See the
    # forward-direction comment above for the rationale.
    [[ "$base" == consensus-candidate-* ]] && continue
    role="$base"
    canonical=".agents/${role}.md"
    if [[ -f "$canonical" ]]; then
      pass "$platform overlay $overlay has canonical $canonical"
    else
      fail "$platform overlay $overlay has no canonical $canonical (stale overlay; remove it or restore the canonical role file)"
    fi
  done
done

echo ""
