#!/usr/bin/env python3
"""Combine objective and subjective grades into final scores."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grading_lib import compile_final_row, utc_now, write_json  # noqa: E402

STANDARD_CATEGORIES = [
    "correctness",
    "quality",
    "process",
    "reliability",
    "latency",
]
PIPELINE_CATEGORIES = STANDARD_CATEGORIES + ["coordination"]


def _rubric_id_from_bundles(bundles: list[Path]) -> str:
    for bundle in bundles:
        obj_path = bundle / "objective-grade.json"
        if obj_path.is_file():
            obj = json.loads(obj_path.read_text(encoding="utf-8"))
            return str(obj.get("rubric_id", "rubric.v1"))
    return "rubric.v1"


def _category_columns(rows: list[dict], rubric_id: str) -> list[str]:
    if rubric_id == "rubric.pipeline.v1":
        return PIPELINE_CATEGORIES
    for row in rows:
        cats = row.get("categories", {})
        if "coordination" in cats:
            return PIPELINE_CATEGORIES
    return STANDARD_CATEGORIES


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-root", type=Path, required=True)
    parser.add_argument("--grader-id", default="")
    parser.add_argument("--median-subjective", action="store_true")
    parser.add_argument("--out", type=Path, help="TSV path (default: bundle-root/final-grades.tsv)")
    args = parser.parse_args()

    root = args.bundle_root.resolve()
    bundles = sorted(p for p in root.glob("eval-*") if p.is_dir())
    grader_id = args.grader_id or "default"
    rows = []
    for bundle in bundles:
        row = compile_final_row(
            bundle, grader_id, median=args.median_subjective
        )
        if row:
            rows.append(row)

    obj_in = None
    if bundles and (bundles[0] / "objective-input.json").is_file():
        obj_in = json.loads(
            (bundles[0] / "objective-input.json").read_text(encoding="utf-8")
        )

    rubric_id = _rubric_id_from_bundles(bundles)
    category_cols = _category_columns(rows, rubric_id)

    final_json = {
        "schema_version": "benchmark-final-grades.v1",
        "score_set_id": obj_in.get("score_set_id", "unknown") if obj_in else "unknown",
        "task_id": obj_in.get("task_id", "unknown") if obj_in else "unknown",
        "rubric_id": rubric_id,
        "grader_id": grader_id,
        "subjective_aggregation": "median" if args.median_subjective else "single",
        "rows": rows,
        "compiled_at": utc_now(),
    }

    tsv_path = args.out or root / "final-grades.tsv"
    json_path = root / "final-grades.json"
    write_json(json_path, final_json)

    with tsv_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(
            [
                "eval_candidate_id",
                "complete",
                "hard_gate_pass",
                "objective_total",
                "subjective_total",
                "final_total",
                *category_cols,
            ]
        )
        for row in rows:
            cats = row.get("categories", {})
            w.writerow(
                [
                    row["eval_candidate_id"],
                    row["complete"],
                    row.get("hard_gate_pass", False),
                    row.get("objective_total", ""),
                    row.get("subjective_total", ""),
                    row.get("final_total", ""),
                    *[
                        cats.get(cat, {}).get("total", "")
                        for cat in category_cols
                    ],
                ]
            )

    print(f"wrote {json_path} and {tsv_path} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
