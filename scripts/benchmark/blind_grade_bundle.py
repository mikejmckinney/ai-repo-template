#!/usr/bin/env python3
"""Blind subjective JSON for one benchmark bundle (LLM default; heuristic fallback)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blind_grade_heuristic import grade_bundle as grade_heuristic  # noqa: E402
from llm_grade_subjective import grade_bundle as grade_llm  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--grader-id", required=True)
    parser.add_argument("--out", type=Path, help="Write JSON here (default: stdout)")
    parser.add_argument("--heuristic", action="store_true", help="Use offline heuristic grader (not LLM)")
    parser.add_argument("--model", help="Cursor agent model slug (LLM mode only)")
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()

    if args.heuristic:
        doc = grade_heuristic(args.bundle.resolve(), args.grader_id)
    else:
        doc = grade_llm(
            args.bundle.resolve(),
            args.grader_id,
            model=args.model,
            timeout=args.timeout,
        )

    text = json.dumps(doc, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
        mode = "heuristic" if args.heuristic else "llm"
        print(f"wrote {args.out} ({mode}) subjective_total={doc.get('subjective_total')}")
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
