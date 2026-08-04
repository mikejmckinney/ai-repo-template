#!/usr/bin/env python3
"""Extract and validate daily-retro JSON from an issue snapshot comment body."""
from __future__ import annotations

import argparse
import json
import re
import sys


def extract_json_from_snapshot(body: str) -> str:
    if "postmerge-retro:daily-json:truncated" in body:
        raise ValueError(
            "Issue JSON snapshot is truncated; use fix_only with artifact_run_id "
            "(Actions artifact is canonical for full daily-retro.json)"
        )

    match = re.search(r"```json\s*(.*?)\s*```", body, re.DOTALL)
    if not match:
        raise ValueError("Snapshot comment missing ```json block")

    json_text = match.group(1).strip()
    if "TRUNCATED" in json_text:
        raise ValueError(
            "Issue JSON snapshot is truncated; use fix_only with artifact_run_id "
            "(Actions artifact is canonical for full daily-retro.json)"
        )

    try:
        json.loads(json_text)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"Issue JSON snapshot is invalid ({exc}); use fix_only with artifact_run_id"
        ) from exc

    return json_text + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("body_file", type=argparse.FileType("r", encoding="utf-8"))
    args = parser.parse_args()
    body = args.body_file.read()
    try:
        sys.stdout.write(extract_json_from_snapshot(body))
    except ValueError as exc:
        print(f"::error::{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
