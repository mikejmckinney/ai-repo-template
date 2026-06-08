#!/usr/bin/env python3
"""Sync canonical scores, ROI, and table sort order in agent-roi-benchmark-results.md.

Subcommands:
  scores  — inject canonical/obj/subj columns (was update-results-canonical-scores.py)
  roi     — recompute ROI numerators for all stages
  sort    — apply documented per-table sort order + sort notes
  all     — scores, then roi, then sort
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_RESULTS = REPO / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"


def cmd_scores(path: Path) -> None:
    subprocess.run([sys.executable, str(HERE / "update-results-canonical-scores.py"), str(path)], check=True)


def cmd_roi(path: Path) -> None:
    for name in (
        "update-stage-1-roi.py",
        "update-stage-1c-roi.py",
        "update-stage-1d-roi.py",
        "update-stage-1-pipeline-roi.py",
        "update-stage-1e-roi.py",
    ):
        subprocess.run([sys.executable, str(HERE / name), str(path)], check=True)


def cmd_sort(path: Path) -> None:
    sys.path.insert(0, str(HERE))
    from results_table_sort import sort_markdown_tables  # noqa: E402

    lines = path.read_text(encoding="utf-8").splitlines()
    out = sort_markdown_tables(lines)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"sorted tables in {path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["scores", "roi", "sort", "all"])
    parser.add_argument("results_md", nargs="?", type=Path, default=DEFAULT_RESULTS)
    args = parser.parse_args()

    if args.command in ("scores", "all"):
        cmd_scores(args.results_md)
    if args.command in ("roi", "all"):
        cmd_roi(args.results_md)
    if args.command in ("sort", "all"):
        cmd_sort(args.results_md)


if __name__ == "__main__":
    main()
