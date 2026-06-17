#!/usr/bin/env python3
"""Build a capped issue-comment body embedding a JSON snapshot."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# GitHub issue comments max ~65536 chars; leave headroom for marker + markdown wrapper.
DEFAULT_MAX_BYTES = 60000
TRUNCATION_NOTICE = (
    "\n\n_Truncated snapshot — retrieve the full JSON from the Actions workflow artifact "
    "(use `artifact_run_id` on fix-only reruns)._"
)


def _compact_json(data: object) -> str:
    return json.dumps(data, separators=(",", ":"), ensure_ascii=False)


def _utf8_len(text: str) -> int:
    return len(text.encode("utf-8"))


def _shrink_finding_body(item: dict, max_bytes: int) -> dict | None:
    if not isinstance(item, dict):
        return None
    body = item.get("body")
    if not isinstance(body, str):
        return item
    shrunk = dict(item)
    text = body
    while text:
        shrunk["body"] = text
        if _utf8_len(_compact_json(shrunk)) <= max_bytes:
            return shrunk
        text = text[: max(0, len(text) - 1024)]
    shrunk["body"] = ""
    return shrunk if _utf8_len(_compact_json(shrunk)) <= max_bytes else None


def shrink_json_object(data: object, max_bytes: int) -> tuple[str, bool]:
    """Return valid JSON text that fits max_bytes; trim findings[] when needed."""
    compact = _compact_json(data)
    if _utf8_len(compact) <= max_bytes:
        return compact, False

    if not isinstance(data, dict):
        minimal = {"truncated": True, "note": "retrieve full JSON from Actions artifact"}
        return _compact_json(minimal), True

    original_findings = data.get("findings")
    if not isinstance(original_findings, list):
        minimal = {
            "run_date": data.get("run_date"),
            "truncated": True,
            "note": "retrieve full JSON from Actions artifact",
        }
        return _compact_json(minimal), True

    findings = list(original_findings)
    truncated = False
    while findings:
        trial = {**data, "findings": findings}
        compact = _compact_json(trial)
        if _utf8_len(compact) <= max_bytes:
            return compact, truncated or len(findings) < len(original_findings)

        if len(findings) == 1:
            shrunk = _shrink_finding_body(findings[0], max_bytes - 256)
            if shrunk is not None:
                trial = {**data, "findings": [shrunk]}
                compact = _compact_json(trial)
                if _utf8_len(compact) <= max_bytes:
                    return compact, True
            break
        findings.pop()
        truncated = True

    minimal = {
        "run_date": data.get("run_date"),
        "truncated": True,
        "note": "retrieve full JSON from Actions artifact",
    }
    return _compact_json(minimal), True


def build_comment_body(
    marker: str,
    heading: str,
    intro: str,
    json_text: str,
    max_bytes: int,
) -> str:
    reserve = _utf8_len(TRUNCATION_NOTICE)
    prefix = f"{marker}\n\n## {heading}\n\n{intro}\n\n```json\n"
    suffix = "\n```\n"
    overhead = _utf8_len(prefix + suffix)
    budget = max_bytes - overhead - reserve
    if budget <= 0:
        raise ValueError(f"max_bytes={max_bytes} too small for comment wrapper")

    data = json.loads(json_text)
    compact, truncated = shrink_json_object(data, budget)
    body = prefix + compact + suffix
    if truncated:
        body += TRUNCATION_NOTICE
        if _utf8_len(body) > max_bytes:
            # Last resort: drop findings entirely.
            compact, _ = shrink_json_object(
                {
                    "run_date": data.get("run_date") if isinstance(data, dict) else None,
                    "truncated": True,
                    "note": "retrieve full JSON from Actions artifact",
                },
                budget,
            )
            body = prefix + compact + suffix + TRUNCATION_NOTICE
        print(
            f"::warning::JSON snapshot truncated to fit issue comment size ({max_bytes} bytes); "
            "see Actions artifact for the full file",
            file=sys.stderr,
        )
    return body


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--marker", required=True)
    parser.add_argument("--heading", required=True)
    parser.add_argument("--intro", required=True)
    parser.add_argument("--json-file", required=True)
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    args = parser.parse_args()

    json_text = Path(args.json_file).read_text(encoding="utf-8")
    body = build_comment_body(
        args.marker,
        args.heading,
        args.intro,
        json_text,
        args.max_bytes,
    )
    sys.stdout.write(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
