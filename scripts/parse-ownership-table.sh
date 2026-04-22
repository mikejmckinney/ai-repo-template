#!/usr/bin/env bash
# Parse the "Ownership Table" out of .context/rules/agent_ownership.md
# (or any markdown file with the same table shape) and emit one
# `role<TAB>top-level-prefix` line per (role, glob) pair, sorted unique.
#
# Contract:
#   stdin  — markdown containing an Ownership Table (other content is
#            ignored; only rows whose first column is a known role name
#            are matched).
#   stdout — `role<TAB>prefix` lines, sorted unique. Inline parenthetical
#            qualifiers (e.g. `docs/** (except docs/decisions/**)`) are
#            stripped before the comma split so their interior commas
#            don't shatter the row. `nothing` / `nothing (...)` globs
#            are dropped. `/**` and `/*` suffixes are reduced to the
#            top-level prefix.
#   exit   — 0 even on zero matches. Callers decide fail-soft policy
#            (the workflow logs a warning and skips soft classification
#            when the output is empty; the unit test hard-fails).
#
# Source of truth for the parser. Callers:
#   - .github/workflows/agent-parallelism-report.yml  (producer)
#   - scripts/test-parallelism-report-parser.sh        (unit test)
#
# See ADR-009 §Implementation for design rationale.

set -euo pipefail

awk -F'|' '
  /^\| *(Analyst|Architect|Frontend|Backend|PM|QA|DevOps|Docs|Judge|Critic) +\|/ {
    role=$2
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", role)
    globs=$3
    gsub(/`/, "", globs)
    # Strip inline parenthetical qualifiers BEFORE the comma split.
    # Some rows contain notes like
    #   `docs/** (except docs/decisions/**, docs/research/**)`
    # whose interior commas would otherwise corrupt the split.
    gsub(/ *\([^)]*\)/, "", globs)
    n=split(globs, parts, ",")
    for (i=1;i<=n;i++) {
      g=parts[i]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", g)
      if (g == "" || g == "nothing (research-only)" || g ~ /^nothing/) continue
      sub(/\/\*\*$/, "", g)
      sub(/\/\*$/, "", g)
      if (g != "") print role "\t" g
    }
  }
' | sort -u
