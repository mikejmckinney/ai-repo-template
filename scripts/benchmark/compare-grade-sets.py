#!/usr/bin/env python3
"""Compare two benchmark grade sets for drift / inter-rater reliability."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grading_lib import spearman_rho, write_json  # noqa: E402


def load_final(path: Path) -> dict:
    if path.is_dir():
        path = path / "final-grades.json"
    return json.loads(path.read_text(encoding="utf-8"))


def load_sealed_map(root: Path) -> dict[str, str]:
    tsv = root / "sealed-eval-map.tsv"
    if not tsv.is_file():
        return {}
    mapping: dict[str, str] = {}
    with tsv.open(encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            if row.get("eval_candidate_id", "").startswith("#"):
                continue
            key = row.get("sealed_candidate_key") or row.get("eval_candidate_id", "")
            mapping[row["eval_candidate_id"]] = key
    return mapping


def index_rows(final: dict) -> dict[str, dict]:
    return {r["eval_candidate_id"]: r for r in final.get("rows", [])}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--left", type=Path, required=True)
    parser.add_argument("--right", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    left_final = load_final(args.left)
    right_final = load_final(args.right)
    left_root = args.left if args.left.is_dir() else args.left.parent
    right_root = args.right if args.right.is_dir() else args.right.parent

    left_rows = index_rows(left_final)
    right_rows = index_rows(right_final)
    left_map = load_sealed_map(left_root)
    right_map = load_sealed_map(right_root)

    paired = []
    adjudication = []
    for eval_id, lrow in left_rows.items():
        r_eval = eval_id
        if left_map and right_map:
            sealed = left_map.get(eval_id)
            r_eval = next((k for k, v in right_map.items() if v == sealed), eval_id)
        rrow = right_rows.get(r_eval)
        if not rrow:
            continue
        lscore = lrow.get("final_total")
        rscore = rrow.get("final_total")
        if lscore is None or rscore is None:
            continue
        delta = int(rscore) - int(lscore)
        paired.append(
            {
                "eval_candidate_id": eval_id,
                "left_score": lscore,
                "right_score": rscore,
                "delta": delta,
                "left_rank_candidate": lscore,
            }
        )
        if abs(delta) >= 8:
            adjudication.append({"eval_candidate_id": eval_id, "reason": f"score_delta={delta}"})

    left_scores = [p["left_score"] for p in paired]
    right_scores = [p["right_score"] for p in paired]
    rho = spearman_rho(left_scores, right_scores)

    left_top = max(paired, key=lambda p: p["left_score"])["eval_candidate_id"] if paired else None
    right_top = max(paired, key=lambda p: p["right_score"])["eval_candidate_id"] if paired else None
    top1_agree = left_top == right_top

    report = {
        "left_score_set_id": left_final.get("score_set_id"),
        "right_score_set_id": right_final.get("score_set_id"),
        "paired_count": len(paired),
        "paired_rows": paired,
        "spearman_rho": rho,
        "top1_agreement": top1_agree,
        "adjudication_required": adjudication,
        "limitations": (
            "Compared by eval_candidate_id only"
            if not (left_map and right_map)
            else "Compared via sealed_candidate_key when available"
        ),
    }
    write_json(args.out, report)
    print(f"wrote {args.out} paired={len(paired)} rho={rho}")


if __name__ == "__main__":
    main()
