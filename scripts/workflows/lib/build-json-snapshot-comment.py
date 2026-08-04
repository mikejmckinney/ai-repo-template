#!/usr/bin/env python3
"""Build a capped issue-comment body embedding a JSON snapshot."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# GitHub issue comments max ~65536 chars; leave headroom for marker + markdown wrapper.
DEFAULT_MAX_BYTES = 60000


def build_comment_body(
    marker: str,
    heading: str,
    intro: str,
    json_text: str,
    max_bytes: int,
) -> str:
    prefix = f"{marker}\n\n## {heading}\n\n{intro}\n\n```json\n"
    suffix = "\n```\n"
    overhead = len((prefix + suffix).encode("utf-8"))
    budget = max_bytes - overhead
    if budget <= 0:
        raise ValueError(f"max_bytes={max_bytes} too small for comment wrapper")

    json_bytes = json_text.encode("utf-8")
    truncated = False
    if len(json_bytes) > budget:
        truncated = True
        json_text = json.dumps(
            {
                "snapshot_status": "TRUNCATED",
                "original_bytes": len(json_bytes),
                "recovery": "Retrieve the full JSON from the Actions workflow artifact.",
            },
            indent=2,
        )
        if len(json_text.encode("utf-8")) > budget:
            raise ValueError(f"max_bytes={max_bytes} too small for truncation envelope")

    body = prefix + json_text + suffix
    if truncated:
        body += "\n<!-- postmerge-retro:daily-json:truncated -->\n"
        print(
            f"::warning::JSON snapshot truncated to fit issue comment size ({max_bytes} bytes); "
            "fix_only must use artifact_run_id — issue comment is not restorable",
            file=sys.stderr,
        )
    return body


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--marker", required=True)
    parser.add_argument("--heading", required=True)
    parser.add_argument("--intro", required=True)
    parser.add_argument("--json-file", required=True)
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    args = parser.parse_args()

    json_text = Path(args.json_file).read_text(encoding="utf-8")
    body = build_comment_body(
        args.marker,
        args.heading,
        args.intro,
        json_text,
        args.max_bytes,
    )
    sys.stdout.write(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
