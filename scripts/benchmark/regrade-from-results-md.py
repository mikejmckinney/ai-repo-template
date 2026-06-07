#!/usr/bin/env python3
"""Extract Stage 1 monolithic scored rows from agent-roi-benchmark-results.md."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RESULTS_MD = REPO_ROOT / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"
RUNNER = REPO_ROOT / "scripts/benchmark"

TASK_BY_SECTION = {
    "Class A:": "opfit-281-class-a-premerge",
    "Class B:": "opfit-326-class-b-premerge",
}

SUBJECTIVE_MAX = {
    "correctness": 10,
    "quality": 15,
    "process": 5,
    "reliability": 5,
}
CAT_MAP = {
    "correctness": "correctness",
    "quality": "quality",
    "process": "process",
    "reliability": "reliability",
}


def parse_monolithic_rows(text: str) -> list[dict]:
    rows: list[dict] = []
    current_task: str | None = None
    in_table = False

    for line in text.splitlines():
        if line.startswith("## Class A:"):
            current_task = TASK_BY_SECTION["Class A:"]
            in_table = False
            continue
        if line.startswith("## Class B:"):
            current_task = TASK_BY_SECTION["Class B:"]
            in_table = False
            continue
        if line.startswith("### ") or line.startswith("## Stage 1C"):
            if current_task and in_table:
                break
            in_table = False
            continue
        if not current_task:
            continue
        if line.startswith("| Alias | Run | Gates |"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|"):
            in_table = False
            continue
        if line.startswith("|---"):
            continue
        if "`" not in line:
            in_table = False
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 12:
            continue
        alias = parts[0].strip("`")
        run = int(parts[1])
        gates = parts[2]
        scores = {
            "correctness": int(parts[3]),
            "quality": int(parts[4]),
            "process": int(parts[5]),
            "reliability": int(parts[6]),
            "latency": int(parts[7]),
            "total": int(parts[8]),
        }
        summary = parts[11] if len(parts) > 11 else ""
        rows.append(
            {
                "task": current_task,
                "alias": alias,
                "run": run,
                "gates": gates,
                "scores": scores,
                "summary": summary,
            }
        )
    return rows


def write_manifest(rows: list[dict], out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# alias\trun_index\tlegacy_total\tgates"]
    for row in rows:
        lines.append(
            f"{row['alias']}\t{row['run']}\t{row['scores']['total']}\t{row['gates']}"
        )
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def load_sealed_map(bundle_root: Path) -> dict[str, str]:
    sealed = bundle_root / "sealed-eval-map.tsv"
    alias_by_eval: dict[str, str] = {}
    for line in sealed.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        cols = line.split("\t")
        if cols[0] == "eval_candidate_id":
            continue
        alias_by_eval[cols[0]] = cols[2]
    return alias_by_eval


def generate_responses(
    rows: list[dict],
    *,
    task: str,
    score_set: str,
    grader_id: str,
    out_dir: Path,
) -> None:
    bundle_root = RUNNER / "grade-bundles" / task / score_set
    alias_by_eval = load_sealed_map(bundle_root)
    eval_by_alias_run: dict[tuple[str, int], str] = {}
    for line in (bundle_root / "sealed-eval-map.tsv").read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        cols = line.split("\t")
        if cols[0] == "eval_candidate_id" or not cols[3].isdigit():
            continue
        eval_by_alias_run[(cols[2], int(cols[3]))] = cols[0]

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for row in rows:
        if row["task"] != task:
            continue
        eval_id = eval_by_alias_run.get((row["alias"], row["run"]))
        if not eval_id:
            print(f"warn: no bundle for {row['alias']} r{row['run']}", file=sys.stderr)
            continue
        obj_path = bundle_root / eval_id / "objective-grade.json"
        if not obj_path.is_file():
            print(f"warn: missing objective grade for {eval_id}", file=sys.stderr)
            continue
        objective = json.loads(obj_path.read_text(encoding="utf-8"))
        cats = {}
        sub_total = 0
        for leg, cat in CAT_MAP.items():
            mx = SUBJECTIVE_MAX[cat]
            obj_pts = int(objective["categories"][cat]["objective_points"])
            raw = row["scores"][leg] - obj_pts
            pts = max(0, min(mx, raw))
            cats[cat] = {
                "subjective_points": pts,
                "max_subjective_points": mx,
                "rationale": row["summary"]
                or f"Legacy results.md residual for {cat} ({leg}={row['scores'][leg]}, objective={obj_pts}).",
            }
            sub_total += pts
        doc = {
            "schema_version": "benchmark-subjective-grade.v1",
            "score_set_id": score_set,
            "eval_candidate_id": eval_id,
            "grader_id": grader_id,
            "grader_prompt_id": "model-roi-grader-v1",
            "rubric_id": "rubric.v1",
            "categories": cats,
            "subjective_total": sub_total,
            "citations": [
                {
                    "bundle_ref": "diff.patch",
                    "claim": row["summary"] or "Legacy blind grade from agent-roi-benchmark-results.md.",
                },
                {
                    "bundle_ref": "objective-grade.json#evidence",
                    "claim": "Objective automation applied before legacy subjective residual mapping.",
                },
            ],
            "graded_at": now,
        }
        group_dir = out_dir / task
        group_dir.mkdir(parents=True, exist_ok=True)
        out_path = group_dir / f"{eval_id}.json"
        out_path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")


def cmd_extract(args: argparse.Namespace) -> None:
    text = Path(args.results_md).read_text(encoding="utf-8")
    rows = parse_monolithic_rows(text)
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
    rows = parse_monolithic_rows(text)
    for task in sorted({r["task"] for r in rows}):
        task_rows = [r for r in rows if r["task"] == task]
        generate_responses(
            task_rows,
            task=task,
            score_set=args.score_set,
            grader_id=args.grader_id,
            out_dir=Path(args.responses_dir),
        )
        print(f"responses for {task}: {len(task_rows)} evals -> {args.responses_dir}/{task}/")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    ext = sub.add_parser("extract", help="Write per-task alias/run manifests")
    ext.add_argument(
        "--results-md",
        type=Path,
        default=RESULTS_MD,
    )
    ext.add_argument(
        "--out-dir",
        type=Path,
        default=RUNNER / "grade-bundles/stage-1-canonical-v1-manifests",
    )
    ext.set_defaults(func=cmd_extract)

    resp = sub.add_parser("responses", help="Generate subjective JSON from legacy category scores")
    resp.add_argument(
        "--results-md",
        type=Path,
        default=RESULTS_MD,
    )
    resp.add_argument("--score-set", default="stage-1-canonical-v1")
    resp.add_argument("--grader-id", default="results-md-legacy-v1")
    resp.add_argument(
        "--responses-dir",
        type=Path,
        default=RUNNER / "stage-1-responses",
    )
    resp.set_defaults(func=cmd_responses)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
