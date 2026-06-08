#!/usr/bin/env python3
"""Invoke an LLM on each bundle's subjective-prompt.md (true blind grading)."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grading_lib import (  # noqa: E402
    die,
    load_json,
    load_rubric_by_id,
    rubric_limits,
    utc_now,
    validate_subjective_grade,
    write_json,
)

REPO = Path(__file__).resolve().parents[2]

PIPELINE_AUGMENT = """
## Pipeline rubric override

This bundle uses `rubric.pipeline.v1` (not `rubric.v1`). Score these subjective maxima:
- Correctness: 10
- Quality: 12
- Process: 5
- Reliability: 5
- Coordination: 10 (subjective only; observable multi-role orchestration evidence)
- Latency: 0 (objective only)

Set `rubric_id` to `rubric.pipeline.v1` in your JSON output and include all categories above.
"""


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def compose_prompt(bundle: Path) -> str:
    objective = load_json(bundle / "objective-grade.json")
    parts = [read_text(bundle / "subjective-prompt.md")]
    diff = read_text(bundle / "diff.patch")
    if diff.strip():
        parts.extend(["\n\n---\n\n## Bundle: diff.patch\n\n```diff\n", diff, "\n```\n"])
    files = read_text(bundle / "files-changed.txt")
    if files.strip():
        parts.extend(["\n\n---\n\n## Bundle: files-changed.txt\n\n```\n", files, "\n```\n"])
    if objective.get("rubric_id") == "rubric.pipeline.v1":
        parts.append(PIPELINE_AUGMENT)
    parts.append(
        f"\n\n---\n\nGrade this bundle now. Output **JSON only** (no markdown fences). "
        f"Use grader_id exactly as provided. "
        f"score_set_id={objective['score_set_id']} "
        f"eval_candidate_id={objective['eval_candidate_id']} "
        f"rubric_id={objective.get('rubric_id', 'rubric.v1')}.\n"
    )
    return "".join(parts)


def extract_json(text: str) -> dict:
    text = text.strip()
    if not text:
        die("empty LLM response")
    fence = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if fence:
        text = fence.group(1)
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        die(f"no JSON object in LLM response: {text[:400]!r}")
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError as exc:
        die(f"invalid JSON from LLM: {exc}; snippet={text[start : start + 400]!r}")


def normalize_grade(data: dict, bundle: Path, grader_id: str) -> dict:
    objective = load_json(bundle / "objective-grade.json")
    rubric_id = objective.get("rubric_id", "rubric.v1")
    _, sub_max, _ = rubric_limits(load_rubric_by_id(rubric_id))

    data["schema_version"] = "benchmark-subjective-grade.v1"
    data["score_set_id"] = objective["score_set_id"]
    data["eval_candidate_id"] = objective["eval_candidate_id"]
    data["grader_id"] = grader_id
    data["grader_prompt_id"] = "model-roi-grader-v1"
    data["rubric_id"] = rubric_id
    data.setdefault("uncertainty_notes", [])
    data.setdefault("citations", [])

    cats = data.setdefault("categories", {})
    total = 0
    for cat, mx in sub_max.items():
        if mx <= 0:
            continue
        block = cats.setdefault(cat, {})
        pts = int(block.get("subjective_points", 0))
        pts = max(0, min(mx, pts))
        block["subjective_points"] = pts
        block["max_subjective_points"] = mx
        block.setdefault("rationale", "LLM blind grade from bundle evidence.")
        total += pts
    data["subjective_total"] = total
    data["graded_at"] = utc_now()
    return data


def invoke_cursor_agent(prompt: str, model: str | None, timeout: int) -> str:
    """Run cursor agent in a new session so timeout can kill the whole tree."""
    cmd = ["agent", "--print", "--mode", "ask", "--output-format", "text"]
    if model:
        cmd.extend(["--model", model])
    env = os.environ.copy()
    try:
        proc = subprocess.run(
            cmd,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(REPO),
            env=env,
            start_new_session=True,
        )
    except subprocess.TimeoutExpired as exc:
        die(
            f"agent timed out after {timeout}s "
            f"(prompt_bytes={len(prompt)}); partial_out={str(exc.stdout or '')[:200]!r}"
        )
    if proc.returncode != 0:
        die(f"agent failed (rc={proc.returncode}): {proc.stderr.strip() or proc.stdout[:500]}")
    return proc.stdout


def grade_bundle(
    bundle: Path,
    grader_id: str,
    *,
    model: str | None = None,
    timeout: int = 300,
) -> dict:
    bundle = bundle.resolve()
    prompt_path = bundle / "subjective-prompt.md"
    if not prompt_path.is_file():
        die(f"missing subjective-prompt.md in {bundle}")
    prompt = compose_prompt(bundle)
    raw = invoke_cursor_agent(prompt, model, timeout)
    data = normalize_grade(extract_json(raw), bundle, grader_id)
    errors = validate_subjective_grade(data, bundle)
    if data.get("grader_id") != grader_id:
        errors.append("grader_id mismatch after normalize")
    if errors:
        die(f"validation failed for {bundle.name}: {'; '.join(errors)}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--grader-id", required=True)
    parser.add_argument("--out", type=Path, help="Write JSON (default: stdout)")
    parser.add_argument("--model", help="Cursor agent model slug (optional)")
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    doc = grade_bundle(args.bundle, args.grader_id, model=args.model, timeout=args.timeout)
    text = json.dumps(doc, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
        print(f"wrote {args.out} subjective_total={doc['subjective_total']}")
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
