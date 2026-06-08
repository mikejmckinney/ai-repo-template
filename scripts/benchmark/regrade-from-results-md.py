#!/usr/bin/env python3
"""Extract scored rows from agent-roi-benchmark-results.md and bootstrap subjective JSON."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from regrade_results_lib import (  # noqa: E402
    RESULTS_MD,
    RUNNER,
    parse_rows_for_stage,
    write_manifest,
    generate_responses,
)

STAGE_DEFAULTS = {
    "1": {
        "score_set": "stage-1-canonical-v1",
        "manifest_dir": "stage-1-canonical-v1-manifests",
        "responses_dir": "stage-1-responses",
        "grader_id": "results-md-legacy-v1",
        "rubric_profile": "standard",
    },
    "1c": {
        "score_set": "stage-1c-canonical-v1",
        "manifest_dir": "stage-1c-canonical-v1-manifests",
        "responses_dir": "stage-1c-responses",
        "grader_id": "results-md-legacy-v1",
        "rubric_profile": "standard",
    },
    "1d": {
        "score_set": "stage-1d-canonical-v1",
        "manifest_dir": "stage-1d-canonical-v1-manifests",
        "responses_dir": "stage-1d-responses",
        "grader_id": "results-md-legacy-v1",
        "rubric_profile": "standard",
    },
    "pipeline": {
        "score_set": "stage-1-pipeline-canonical-v1",
        "manifest_dir": "stage-1-pipeline-canonical-v1-manifests",
        "responses_dir": "stage-1-pipeline-responses",
        "grader_id": "results-md-legacy-v1",
        "rubric_profile": "pipeline",
    },
}


def cmd_extract(args: argparse.Namespace) -> None:
    text = Path(args.results_md).read_text(encoding="utf-8")
    rows = parse_rows_for_stage(args.stage, text)
    by_task: dict[str, list[dict]] = {}
    for row in rows:
        by_task.setdefault(row["task"], []).append(row)
    out_base = Path(args.out_dir)
    for task, task_rows in by_task.items():
        manifest = out_base / f"{task}-manifest.tsv"
        write_manifest(task_rows, manifest)
        print(f"wrote {manifest} ({len(task_rows)} rows)")


def cmd_responses(args: argparse.Namespace) -> None:
    text = Path(args.results_md).read_text(encoding="utf-8")
    rows = parse_rows_for_stage(args.stage, text)
    defaults = STAGE_DEFAULTS[args.stage]
    profile = args.rubric_profile or defaults["rubric_profile"]
    for task in sorted({r["task"] for r in rows}):
        task_rows = [r for r in rows if r["task"] == task]
        row_profile = task_rows[0].get("rubric_profile", profile) if task_rows else profile
        generate_responses(
            task_rows,
            task=task,
            score_set=args.score_set,
            grader_id=args.grader_id,
            out_dir=Path(args.responses_dir),
            rubric_profile=row_profile,
        )
        print(f"responses for {task}: {len(task_rows)} evals -> {args.responses_dir}/{task}/")


def add_stage_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--stage",
        choices=sorted(STAGE_DEFAULTS),
        default="1",
        help="Benchmark stage to parse (default: 1)",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    ext = sub.add_parser("extract", help="Write per-task alias/run manifests")
    add_stage_args(ext)
    ext.add_argument("--results-md", type=Path, default=RESULTS_MD)
    ext.add_argument(
        "--out-dir",
        type=Path,
        default=None,
    )
    ext.set_defaults(func=cmd_extract)

    resp = sub.add_parser("responses", help="Generate subjective JSON from legacy category scores")
    add_stage_args(resp)
    resp.add_argument("--results-md", type=Path, default=RESULTS_MD)
    resp.add_argument("--score-set", default=None)
    resp.add_argument("--grader-id", default=None)
    resp.add_argument("--rubric-profile", default=None)
    resp.add_argument("--responses-dir", type=Path, default=None)
    resp.set_defaults(func=cmd_responses)

    args = parser.parse_args()
    defaults = STAGE_DEFAULTS[args.stage]
    if args.cmd == "extract" and args.out_dir is None:
        args.out_dir = RUNNER / f"grade-bundles/{defaults['manifest_dir']}"
    if args.cmd == "responses":
        if args.score_set is None:
            args.score_set = defaults["score_set"]
        if args.grader_id is None:
            args.grader_id = defaults["grader_id"]
        if args.responses_dir is None:
            args.responses_dir = RUNNER / defaults["responses_dir"]
    args.func(args)


if __name__ == "__main__":
    main()
