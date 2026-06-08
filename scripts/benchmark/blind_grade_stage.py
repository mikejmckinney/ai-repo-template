#!/usr/bin/env python3
"""Batch LLM blind subjective JSON for all eval bundles in a stage score set."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BUNDLES = REPO / "scripts/benchmark/grade-bundles"
RUNNER = REPO / "scripts/benchmark"

STAGE_1E_PREFIX = "stage-1e-canonical-v1"
STAGE_1E_RESP = "stage-1e-llm-responses-v1"
STAGE_1E_GROUPS = (
    ("ctx-a-baseline", "opfit-281-class-a-premerge"),
    ("ctx-a-core-min", "opfit-281-class-a-premerge"),
    ("ctx-a-class-a-process", "opfit-281-class-a-premerge"),
    ("ctx-a-full-rules", "opfit-281-class-a-premerge"),
    ("ctx-b-baseline", "opfit-326-class-b-premerge"),
    ("ctx-b-core-min", "opfit-326-class-b-premerge"),
    ("ctx-b-class-b-implementation", "opfit-326-class-b-premerge"),
    ("ctx-b-full-rules", "opfit-326-class-b-premerge"),
)

STAGE_TASKS = {
    "1": (
        "stage-1-canonical-v1",
        "stage-1-llm-responses-v1",
        ("opfit-281-class-a-premerge", "opfit-326-class-b-premerge"),
    ),
    "1c": (
        "stage-1c-canonical-v1",
        "stage-llm-responses-v1",
        (
            "opfit-281-class-a-premerge-context-injected",
            "opfit-326-class-b-premerge-context-injected",
        ),
    ),
    "1d": (
        "stage-1d-canonical-v1",
        "stage-llm-responses-v1",
        ("opfit-281-class-a-premerge", "opfit-326-class-b-premerge"),
    ),
    "pipeline": (
        "stage-1-pipeline-canonical-v1",
        "stage-llm-responses-v1",
        (
            "opfit-281-class-a-premerge-pipeline",
            "opfit-326-class-b-premerge-pipeline",
        ),
    ),
}


STAGE_CHOICES = sorted(STAGE_TASKS, key=lambda s: (s != "1", s)) + ["1e"]


def grade_1e(args: argparse.Namespace) -> tuple[int, int]:
    out_base = RUNNER / STAGE_1E_RESP
    script = RUNNER / "blind_grade_bundle.py"
    n = skipped = 0
    for run_group, task in STAGE_1E_GROUPS:
        score_set = f"{STAGE_1E_PREFIX}-{run_group}"
        root = BUNDLES / task / score_set
        if not root.is_dir():
            print(f"warn: missing {root}", file=sys.stderr)
            continue
        for bundle in sorted(root.glob("eval-*")):
            if not (bundle / "subjective-prompt.md").is_file():
                continue
            out = out_base / run_group / f"{bundle.name}.json"
            if args.skip_existing and out.is_file():
                skipped += 1
                continue
            cmd = [
                sys.executable,
                str(script),
                "--bundle",
                str(bundle),
                "--grader-id",
                args.grader_id,
                "--out",
                str(out),
                "--timeout",
                str(args.timeout),
            ]
            if args.model:
                cmd.extend(["--model", args.model])
            if args.heuristic:
                cmd.append("--heuristic")
            print(f"grading {run_group}/{bundle.name} ...", flush=True)
            subprocess.run(cmd, check=True, timeout=args.timeout + 60)
            n += 1
    return n, skipped


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=STAGE_CHOICES, required=True)
    parser.add_argument("--grader-id", default="cursor-llm-blind-v1")
    parser.add_argument("--model", help="Cursor agent model slug")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument("--heuristic", action="store_true", help="Offline heuristic fallback")
    args = parser.parse_args()

    if args.stage == "1e":
        n, skipped = grade_1e(args)
        mode = "heuristic" if args.heuristic else "llm"
        out_base = RUNNER / STAGE_1E_RESP
        print(
            f"blind-graded {n} bundles ({mode}) -> {out_base}/"
            + (f" ({skipped} skipped)" if skipped else "")
        )
        return

    score_set, resp_subdir, tasks = STAGE_TASKS[args.stage]
    out_base = RUNNER / resp_subdir
    script = RUNNER / "blind_grade_bundle.py"
    n = 0
    skipped = 0
    for task in tasks:
        root = BUNDLES / task / score_set
        if not root.is_dir():
            print(f"warn: missing {root}", file=sys.stderr)
            continue
        for bundle in sorted(root.glob("eval-*")):
            if not (bundle / "subjective-prompt.md").is_file():
                continue
            out = out_base / task / f"{bundle.name}.json"
            if args.skip_existing and out.is_file():
                skipped += 1
                continue
            cmd = [
                sys.executable,
                str(script),
                "--bundle",
                str(bundle),
                "--grader-id",
                args.grader_id,
                "--out",
                str(out),
                "--timeout",
                str(args.timeout),
            ]
            if args.model:
                cmd.extend(["--model", args.model])
            if args.heuristic:
                cmd.append("--heuristic")
            print(f"grading {task}/{bundle.name} ...", flush=True)
            subprocess.run(cmd, check=True, timeout=args.timeout + 60)
            n += 1
    mode = "heuristic" if args.heuristic else "llm"
    print(f"blind-graded {n} bundles ({mode}) -> {out_base}/" + (f" ({skipped} skipped)" if skipped else ""))


if __name__ == "__main__":
    main()
