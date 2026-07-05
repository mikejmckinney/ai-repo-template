#!/usr/bin/env bash
# Emit role<TAB>top-level-prefix lines from canonical .agents/*.md owned_paths
# frontmatter. Used when .context/rules/agent_ownership.md is absent (ADR-031).
#
# Contract mirrors scripts/parse-ownership-table.sh default mode:
#   stdout — role<TAB>prefix lines, sorted unique (role lowercased)
#   exit   — 0 even on zero matches
#
# Callers: scripts/multi-dispatch-safety.sh (role-glob + soft overlap)

set -euo pipefail

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "$_LIB_DIR/.." && pwd)"

python3 - "$_REPO_ROOT" <<'PY'
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    print(f"load-role-owned-paths.sh: PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(1)

repo_root = Path(sys.argv[1])
agents_dir = repo_root / ".agents"
frontmatter_re = re.compile(r"\A[ \t]*---[ \t]*\n(.*?)\n[ \t]*---", re.S)
pairs: set[tuple[str, str]] = set()

for path in sorted(agents_dir.glob("*.md")):
    if path.name in {"README.md", "_TEMPLATE.md"}:
        continue
    text = path.read_text(encoding="utf-8")
    match = frontmatter_re.search(text)
    if not match:
        continue
    data = yaml.safe_load(match.group(1)) or {}
    role = str(data.get("name") or path.stem).lower()
    for glob in data.get("owned_paths") or []:
        if not isinstance(glob, str):
            continue
        g = glob.strip()
        if not g or g.startswith("#"):
            continue
        g = re.sub(r"/\*\*$", "", g.rstrip("/"))
        g = re.sub(r"/\*$", "", g)
        if not g or re.search(r"nothing", g, re.I):
            continue
        pairs.add((role, g))

for role, prefix in sorted(pairs):
    print(f"{role}\t{prefix}")
PY
