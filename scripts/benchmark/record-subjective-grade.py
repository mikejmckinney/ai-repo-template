#!/usr/bin/env python3
"""Validate and record a subjective grader JSON response."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grading_lib import GRADING_DIR, die, validate_subjective_grade, write_json  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--response", type=Path, required=True)
    parser.add_argument(
        "--schema",
        type=Path,
        default=GRADING_DIR / "subjective-grade.schema.json",
    )
    parser.add_argument("--grader-id", required=True)
    args = parser.parse_args()

    bundle = args.bundle.resolve()
    data = json.loads(args.response.read_text(encoding="utf-8"))
    if not args.schema.is_file():
        die(f"schema not found: {args.schema}")

    errors = validate_subjective_grade(data, bundle)
    if data.get("grader_id") != args.grader_id:
        errors.append("grader_id does not match --grader-id")
    if errors:
        die("; ".join(errors))

    out = bundle / f"subjective-grade.{args.grader_id}.json"
    write_json(out, data)
    print(f"wrote {out} subjective_total={data.get('subjective_total')}")


if __name__ == "__main__":
    main()
