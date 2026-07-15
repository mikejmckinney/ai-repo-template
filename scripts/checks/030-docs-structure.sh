#!/usr/bin/env bash
# scripts/checks/030-docs-structure.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- ADR Index Integrity Check ---
echo "Checking ADR index integrity..."

ADR_INDEX="docs/decisions/README.md"
mapfile -t indexed_adrs < <(rg -o '\./adr-[0-9]{3}-[^)]+\.md' "$ADR_INDEX" | sort -u)

for link in "${indexed_adrs[@]}"; do
  path="docs/decisions/${link#./}"
  if [[ -f "$path" ]]; then
    pass "$path is linked and exists"
  else
    fail "$ADR_INDEX links missing ADR $path"
  fi
done

for path in docs/decisions/adr-[0-9][0-9][0-9]-*.md; do
  name="$(basename "$path")"
  if rg -q -F "$name" "$ADR_INDEX"; then
    pass "$path is indexed"
  else
    fail "$path is missing from $ADR_INDEX"
  fi
done

echo ""
