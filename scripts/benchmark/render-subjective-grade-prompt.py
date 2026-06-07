#!/usr/bin/env python3
"""Render locked subjective grading prompt for a blinded bundle."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PROMPT = REPO_ROOT / ".github/prompts/model-roi-grader-v1.md"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--prompt", type=Path, default=DEFAULT_PROMPT)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    bundle = args.bundle.resolve()
    parts = [
        args.prompt.read_text(encoding="utf-8"),
        "\n\n---\n\n## Bundle: candidate.md\n\n",
        (bundle / "candidate.md").read_text(encoding="utf-8"),
        "\n\n---\n\n## Bundle: objective-grade.json\n\n```json\n",
        (bundle / "objective-grade.json").read_text(encoding="utf-8"),
        "\n```\n",
    ]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("".join(parts), encoding="utf-8")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
