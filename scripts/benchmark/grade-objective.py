#!/usr/bin/env python3
"""Deterministic objective grading for model-ROI benchmark bundles."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grading_lib import (  # noqa: E402
    BUNDLES_DIR,
    GRADING_DIR,
    REPO_ROOT,
    die,
    grade_objective_bundle,
    load_rubric,
    load_task_spec,
    write_json,
)


def main() -> None:
    parser = argparse.ArgumentParser(description="Grade objective benchmark points")
    parser.add_argument("--bundle", type=Path, help="Single bundle directory")
    parser.add_argument("--bundle-root", type=Path, help="Grade all eval-* under root")
    parser.add_argument(
        "--rubric",
        type=Path,
        default=GRADING_DIR / "rubric.v1.json",
    )
    parser.add_argument("--task-spec", type=Path, help="Override task spec path")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--run-checks", action="store_true")
    args = parser.parse_args()

    if not args.bundle and not args.bundle_root:
        die("provide --bundle or --bundle-root")

    rubric = load_rubric(args.rubric)
    bundles: list[Path] = []
    if args.bundle:
        bundles = [args.bundle]
    else:
        root = args.bundle_root
        bundles = sorted(p for p in root.glob("eval-*") if p.is_dir())

    if not bundles:
        die("no bundles found")

    for bundle in bundles:
        obj_in_path = bundle / "objective-input.json"
        if not obj_in_path.is_file():
            die(f"missing objective-input.json in {bundle}")
        task_id = __import__("json").loads(obj_in_path.read_text())["task_id"]
        task_spec = load_json_task(args.task_spec, task_id)
        result = grade_objective_bundle(
            bundle,
            rubric=rubric,
            task_spec=task_spec,
            run_checks=args.run_checks,
            repo_root=args.repo_root,
        )
        out = bundle / "objective-grade.json"
        write_json(out, result)
        print(f"wrote {out} objective_total={result['objective_total']}")


def load_json_task(path: Path | None, task_id: str) -> dict:
    if path:
        import json

        return json.loads(path.read_text(encoding="utf-8"))
    return load_task_spec(task_id)


if __name__ == "__main__":
    main()
