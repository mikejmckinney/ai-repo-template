#!/usr/bin/env python3
"""Deprecated wrapper — use update-benchmark-results.py roi|all."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESULTS = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    HERE.parents[1] / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"
)


def main() -> None:
    subprocess.run(
        [sys.executable, str(HERE / "update-benchmark-results.py"), "roi", str(RESULTS)],
        check=True,
    )


if __name__ == "__main__":
    main()
