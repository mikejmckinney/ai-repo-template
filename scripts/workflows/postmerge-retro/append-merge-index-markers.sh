#!/usr/bin/env bash
# Append merge_commit_sha index markers to an umbrella issue Meta section.
# Markers are HTML comments only (invisible when rendered); Layer A dedupe reads them via gh search.
# Usage: append-merge-index-markers.sh <issue-num> <daily-retro.json>
set -euo pipefail

ISSUE_NUM="${1:-}"
DAILY_JSON="${2:-}"
usage() {
  echo "Usage: append-merge-index-markers.sh <issue-num> <daily-retro.json>" >&2
  exit 2
}
[[ -n "$ISSUE_NUM" && -f "$DAILY_JSON" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

body="$(gh issue view "$ISSUE_NUM" -R "$REPO" --json body --jq .body)"
printf '%s' "$body" >"$WORKDIR/body.md"

python3 - "$DAILY_JSON" "$WORKDIR/body.md" "$WORKDIR/merged.md" <<'PY'
import json
import re
import sys
from pathlib import Path

MERGE_INDEX_START = "<!-- postmerge-retro:merge-index:start -->"
MERGE_INDEX_END = "<!-- postmerge-retro:merge-index:end -->"
MARKER_RE = re.compile(r"<!-- postmerge-retro:merge:[0-9a-f]{7,40} pr:\d+ -->", re.IGNORECASE)
LEGACY_HEADING_RE = re.compile(
    r"\n\*\*Indexed merge commits \(automation\):\*\*\n"
    r"(?:<!-- postmerge-retro:merge:[^>]+ -->\n?)*",
    re.IGNORECASE,
)
LEGACY_INDEX_BLOCK_RE = re.compile(
    rf"\n?{re.escape(MERGE_INDEX_START)}.*?{re.escape(MERGE_INDEX_END)}\n?",
    re.DOTALL | re.IGNORECASE,
)


def _existing_markers(text: str) -> list[str]:
    return MARKER_RE.findall(text)


def _new_markers(daily: dict, body: str) -> list[str]:
    markers: list[str] = []
    for row in daily.get("pr_merges") or []:
        pr = row.get("pr")
        sha = str(row.get("merge_commit_sha") or "").strip().lower()
        if not pr or not sha:
            continue
        marker = f"<!-- postmerge-retro:merge:{sha} pr:{pr} -->"
        if marker not in body and marker not in markers:
            markers.append(marker)
    return markers


def _strip_legacy_visible_blocks(text: str) -> str:
    text = LEGACY_HEADING_RE.sub("\n", text)
    return text


def _strip_merge_index_region(meta_tail: str) -> str:
    meta_tail = LEGACY_INDEX_BLOCK_RE.sub("\n", meta_tail)
    # Orphan markers outside the wrapper (legacy placements before Meta).
    meta_tail = MARKER_RE.sub("", meta_tail)
    return meta_tail


def _merge_index_block(markers: list[str]) -> str:
    if not markers:
        return ""
    lines = [MERGE_INDEX_START, *markers, MERGE_INDEX_END, ""]
    return "\n".join(lines)


daily = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
body_raw = Path(sys.argv[2]).read_text(encoding="utf-8")
out = Path(sys.argv[3])

existing = _existing_markers(body_raw)
body = _strip_legacy_visible_blocks(body_raw)
incoming = _new_markers(daily, body_raw)

if not incoming and not existing:
    out.write_text(body)
    sys.exit(0)

all_markers: list[str] = []
for marker in existing + incoming:
    if marker not in all_markers:
        all_markers.append(marker)

block = _merge_index_block(all_markers)
if not block:
    out.write_text(body)
    sys.exit(0)

if "## Meta" in body:
    head, meta_tail = body.split("## Meta", 1)
    meta_tail = _strip_merge_index_region(meta_tail)
    meta_tail = meta_tail.lstrip("\n")
    merged = head.rstrip() + "\n\n## Meta\n\n" + block + meta_tail
else:
    merged = body.rstrip() + "\n\n## Meta\n\n" + block

out.write_text(merged)
PY

merged="$(cat "$WORKDIR/merged.md")"
if [[ "$merged" != "$body" ]]; then
  gh issue edit "$ISSUE_NUM" -R "$REPO" --body "$merged"
  echo "Appended merge index markers to issue #${ISSUE_NUM}" >&2
fi
