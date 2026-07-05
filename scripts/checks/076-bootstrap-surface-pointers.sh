#!/usr/bin/env bash
# scripts/checks/076-bootstrap-surface-pointers.sh — ADR-031 stale bootstrap pointers.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

echo "Checking bootstrap surface pointers (ADR-031)..."

# Normative rule files removed by ADR-031 Amendment 2026-06-15. Citations in
# bootstrap consumers must not require these paths on disk.
ADR031_RETIRED_RULES=(
  agent_ownership.md
  process_gates.md
  process_model_tier.md
  process_pr_completion.md
  process_role_selection.md
  process_subagent_bootstrap.md
  process_template_detection.md
)

BOOTSTRAP_SCAN_FILES=(
  .github/copilot-instructions.md
  .github/prompts/instruction-compliance-smoke.md
  .context/00_INDEX.md
)
while IFS= read -r -d '' f; do
  BOOTSTRAP_SCAN_FILES+=("$f")
done < <(find .agents -maxdepth 1 -name '*.md' ! -name README.md -print0)

if python3 - "${ADR031_RETIRED_RULES[@]}" -- "${BOOTSTRAP_SCAN_FILES[@]}" <<'PY'; then
import re
import sys
from pathlib import Path

args = sys.argv[1:]
sep = args.index("--")
retired = set(args[:sep])
files = args[sep + 1 :]
retired_res = [
    re.compile(rf"\.context/rules/{re.escape(name)}")
    for name in retired
]
errors = []
for rel in files:
    path = Path(rel)
    if not path.is_file():
        errors.append(f"{rel}: scan target missing")
        continue
    text = path.read_text(encoding="utf-8")
    for rx in retired_res:
        if rx.search(text):
            errors.append(f"{rel}: cites retired rule path {rx.pattern}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
PY
  pass "bootstrap consumers omit ADR-031 retired .context/rules paths"
else
  fail "bootstrap consumers cite ADR-031 retired .context/rules paths"
fi

if python3 - <<'PY'; then
import re
from pathlib import Path

pattern = re.compile(r"`?\.context/rules/[A-Za-z0-9_./-]+\.md`?")
scan = [
    Path(".github/copilot-instructions.md"),
    Path(".github/prompts/instruction-compliance-smoke.md"),
    Path(".context/00_INDEX.md"),
    *sorted(Path(".agents").glob("*.md")),
]
scan = [p for p in scan if p.name not in {"README.md"}]
errors = []
for path in scan:
    if not path.is_file():
        continue
    for match in pattern.findall(path.read_text(encoding="utf-8")):
        rel = match.strip("`")
        if not Path(rel).is_file():
            errors.append(f"{path}: missing cited path {rel}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
PY
  pass "bootstrap consumers cite existing .context/rules paths only"
else
  fail "bootstrap consumers cite missing .context/rules paths"
fi

echo ""
