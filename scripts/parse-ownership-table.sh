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
# Modes:
#   (no args)      Default. Read markdown on stdin, emit role/prefix lines.
#   --list-roles   Print the canonical role list (one per line) that this
#                  parser will match. Used by the unit test to sync-check
#                  against the actual roles defined in agent_ownership.md
#                  so a new role added to the table doesn't silently get
#                  dropped from soft-overlap classification (#119).
#
# Source of truth for the parser. Callers:
#   - .github/workflows/agent-parallelism-report.yml  (producer)
#   - scripts/test-parallelism-report-parser.sh        (unit test)
#
# See ADR-009 §Implementation for design rationale.

set -euo pipefail

# Single source of truth for the role list. Both the awk regex below and
# `--list-roles` read from this one variable, so adding a role is a
# one-line edit. The unit test cross-checks this against the live
# ownership table (see scripts/test-parallelism-report-parser.sh →
# "Role-list sync" block).
ROLES='Analyst|Architect|Frontend|Backend|PM|QA|DevOps|Docs|Judge|Critic'

usage() {
  cat >&2 <<'EOF'
Usage: parse-ownership-table.sh [--list-roles]

  (no args)      Read markdown on stdin, emit `role<TAB>prefix` lines.
  --list-roles   Print the canonical role list (one per line).
EOF
}

if (( $# > 1 )); then
  echo "parse-ownership-table.sh: too many arguments" >&2
  usage
  exit 2
fi

case "${1:-}" in
  '')
    ;;  # default mode: stdin -> role/prefix
  --list-roles)
    printf '%s\n' "$ROLES" | tr '|' '\n'
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "parse-ownership-table.sh: unknown argument: $1" >&2
    usage
    exit 2
    ;;
esac

awk -F'|' -v roles="$ROLES" '
  $0 ~ "^\\| *(" roles ") +\\|" {
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
      if (g == "" || g ~ /^nothing/) continue
      sub(/\/\*\*$/, "", g)
      sub(/\/\*$/, "", g)
      if (g != "") print role "\t" g
    }
  }
' | sort -u
