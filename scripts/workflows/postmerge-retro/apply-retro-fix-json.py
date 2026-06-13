#!/usr/bin/env python3
"""Apply file_edits from Gemini-style retro fix JSON."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: apply-retro-fix-json.py <fix.json> <repo-root>", file=sys.stderr)
        return 2

    data = json.load(open(sys.argv[1], encoding="utf-8"))
    root = Path(sys.argv[2]).resolve()

    edits = data.get("file_edits") or []
    if not isinstance(edits, list) or not edits:
        print("No file_edits to apply", file=sys.stderr)
        return 1

    for i, edit in enumerate(edits):
        if not isinstance(edit, dict):
            print(f"file_edits[{i}] must be object", file=sys.stderr)
            return 1
        rel = edit.get("path")
        content = edit.get("content")
        if not isinstance(rel, str) or not rel.strip():
            print(f"file_edits[{i}].path required", file=sys.stderr)
            return 1
        if ".." in Path(rel).parts:
            print(f"Rejected path traversal: {rel}", file=sys.stderr)
            return 1
        if not isinstance(content, str):
            print(f"file_edits[{i}].content must be string", file=sys.stderr)
            return 1
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        print(f"Wrote {rel}")

    notes = data.get("notes")
    if isinstance(notes, str) and notes.strip():
        notes_path = root / f"retro/fix-notes-{data.get('run_date', 'batch')}.md"
        notes_path.parent.mkdir(parents=True, exist_ok=True)
        notes_path.write_text(notes.strip() + "\n", encoding="utf-8")
        print(f"Wrote {notes_path.relative_to(root)}")

    msg_path = root / ".artifacts/postmerge-retro/fix-commit-message.txt"
    msg_path.parent.mkdir(parents=True, exist_ok=True)
    msg_path.write_text(
        (data.get("commit_message") or "fix: post-merge retro daily fixes").strip() + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
