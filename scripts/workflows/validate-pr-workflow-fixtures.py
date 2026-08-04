#!/usr/bin/env python3
"""Exercise daily and weekly provenance paths with synthetic PR-safe fixtures."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROVENANCE = REPO_ROOT / "scripts/workflows/lib/provider-provenance.py"
DAILY_DIR = REPO_ROOT / "scripts/workflows/postmerge-retro"
WEEKLY_DIR = REPO_ROOT / "scripts/workflows/weekly-review"


def run(*args: object, stdout=None) -> None:
    subprocess.run(
        [str(arg) for arg in args],
        cwd=REPO_ROOT,
        check=True,
        stdout=stdout,
    )


def write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def build_provenance(output_dir: Path) -> dict:
    metadata_path = output_dir / "provider-metadata.json"
    provenance_path = output_dir / "provenance.json"
    write_json(
        metadata_path,
        {
            "provider": "fixture",
            "requested_model": "fixture-requested",
            "observed_model": "fixture-observed",
        },
    )
    with provenance_path.open("w", encoding="utf-8") as output:
        run(sys.executable, PROVENANCE, "normalize", metadata_path, stdout=output)
    return json.loads(provenance_path.read_text(encoding="utf-8"))


def validate_daily(output_dir: Path, provenance: dict) -> None:
    daily_dir = output_dir / "daily"
    daily_dir.mkdir(parents=True, exist_ok=True)
    write_json(daily_dir / "provenance.json", provenance)
    daily = {
        "run_date": "2099-01-01",
        "window_hours": 24,
        "summary": "Synthetic daily workflow smoke.",
        "prs": [1],
        "findings": [],
        "pr_evidence_coverage": [
            {
                "pr": 1,
                "diff_included": 1,
                "diff_total": 1,
                "head_included": 1,
                "head_total": 1,
                "would_truncate": False,
                "evidence_route": "bounded",
                "routing_context": {
                    "adaptive_enabled": True,
                    "provider_resolved": provenance["provider"],
                    "cursor_available": False,
                    "antigravity_available": False,
                    "provenance": provenance,
                },
                "provider_attempts": [
                    {
                        "provider": provenance["provider"],
                        "status": "success",
                        "evidence_route": "bounded",
                    }
                ],
            }
        ],
    }
    daily_path = daily_dir / "daily-retro.json"
    rendered_path = daily_dir / "provenance.md"
    write_json(daily_path, daily)
    run(sys.executable, DAILY_DIR / "validate-postmerge-retro-daily.py", daily_path)
    with rendered_path.open("w", encoding="utf-8") as output:
        run(
            sys.executable,
            DAILY_DIR / "render-evidence-coverage-meta.py",
            daily_path,
            stdout=output,
        )
    rendered = rendered_path.read_text(encoding="utf-8")
    if "requested: fixture-requested" not in rendered:
        raise ValueError("daily fixture omitted requested model")
    if "observed: fixture-observed" not in rendered:
        raise ValueError("daily fixture omitted observed model")


def validate_weekly(output_dir: Path, provenance: dict) -> None:
    weekly_dir = output_dir / "weekly"
    weekly_dir.mkdir(parents=True, exist_ok=True)
    review_path = weekly_dir / "review.json"
    weekly_path = weekly_dir / "weekly-review.json"
    rendered_path = weekly_dir / "provenance.md"
    review = {
        "summary": "Synthetic weekly workflow smoke.",
        "follow_up_issues": [],
    }
    write_json(review_path, review)
    run(sys.executable, WEEKLY_DIR / "validate-weekly-review.py", review_path)
    review["provenance"] = provenance
    review["provider_attempts"] = [
        {"provider": provenance["provider"], "status": "success"}
    ]
    write_json(review_path, review)
    with weekly_path.open("w", encoding="utf-8") as output:
        run(
            sys.executable,
            WEEKLY_DIR / "build-weekly-review-batch.py",
            "2099-W01",
            "2099-01-01",
            review_path,
            stdout=output,
        )
    run(sys.executable, WEEKLY_DIR / "validate-weekly-review-batch.py", weekly_path)
    with rendered_path.open("w", encoding="utf-8") as output:
        run(
            sys.executable,
            WEEKLY_DIR / "render-provider-provenance.py",
            weekly_path,
            stdout=output,
        )
    rendered = rendered_path.read_text(encoding="utf-8")
    if "requested: fixture-requested" not in rendered:
        raise ValueError("weekly fixture omitted requested model")
    if "observed: fixture-observed" not in rendered:
        raise ValueError("weekly fixture omitted observed model")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    provenance = build_provenance(output_dir)
    validate_daily(output_dir, provenance)
    validate_weekly(output_dir, provenance)
    print(f"workflow fixtures are valid: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
