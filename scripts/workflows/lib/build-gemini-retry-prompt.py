#!/usr/bin/env python3
"""Build one bounded corrective prompt after malformed Gemini fix output."""
from __future__ import annotations

import sys
from pathlib import Path

from write_fix_attempt_diagnostic import redact


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: build-gemini-retry-prompt.py <prompt> <parse-error> <retry-prompt>",
            file=sys.stderr,
        )
        return 2
    prompt_path, error_path, output_path = map(Path, sys.argv[1:])
    prompt = prompt_path.read_text(encoding="utf-8")
    try:
        error = error_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        error = "Gemini output did not satisfy the required fix JSON schema."
    correction = f"""

---

## One schema correction retry

The previous response was rejected: {redact(error)[:500]}

Return valid JSON only. The root object must contain `file_edits`,
`commit_message`, and `fix_verify`. Do not include Markdown fences, commentary,
raw command output, or controller-owned execution fields.
"""
    output_path.write_text(prompt + correction, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
