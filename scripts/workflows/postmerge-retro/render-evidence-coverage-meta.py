#!/usr/bin/env python3
"""Render umbrella Meta Evidence coverage lines from pr_evidence_coverage records."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _bool_word(val: bool) -> str:
    return "true" if val else "false"


def _fallback_reason(ctx: dict) -> str:
    provider = ctx.get("provider_resolved", "unknown")
    if not ctx.get("adaptive_enabled"):
        return "adaptive disabled"
    if provider == "cursor" and not ctx.get("cursor_available"):
        return "cursor unavailable"
    if provider == "gemini":
        if not ctx.get("antigravity_available"):
            return "antigravity unavailable"
        if not ctx.get("antigravity_on_truncate", True):
            return "antigravity on truncate disabled"
    if provider == "unknown":
        return "no provider configured"
    return "full-evidence unavailable"


def render_line(record: dict) -> str:
    pr = int(record["pr"])
    diff_included = int(record["diff_included"])
    diff_total = int(record["diff_total"])
    route = str(record.get("evidence_route") or "bounded")
    ctx = record.get("routing_context") or {}
    provider = str(ctx.get("provider_resolved") or "unknown")
    antigravity = _bool_word(bool(ctx.get("antigravity_available")))

    truncated = bool(record.get("would_truncate"))
    diff_part = f"diff {diff_included}/{diff_total}"
    if truncated:
        diff_part += " (truncated)"

    parts = [f"PR #{pr} — {diff_part}", f"route: {route}", f"provider: {provider}"]
    if route == "bounded-fallback":
        parts.append(f"fallback: {_fallback_reason(ctx)}")
    parts.append(f"antigravity: {antigravity}")
    return "- " + "; ".join(parts)


def render_block(records: list[dict]) -> str:
    if not records:
        return ""
    lines = ["**Evidence coverage**", ""]
    for record in sorted(records, key=lambda item: int(item["pr"])):
        lines.append(render_line(record))
    lines.append("")
    return "\n".join(lines)


def _coverage_prs_in_body(body: str) -> set[int]:
    prs: set[int] = set()
    for line in body.splitlines():
        if not line.startswith("- PR #"):
            continue
        try:
            prs.add(int(line.split("PR #", 1)[1].split("—", 1)[0].strip()))
        except ValueError:
            continue
    return prs


def merge_coverage_into_body(body: str, records: list[dict]) -> str:
    if not records:
        return body
    block = render_block(records)
    if "**Evidence coverage**" in body:
        before, _, rest = body.partition("**Evidence coverage**")
        after_lines = rest.splitlines()
        end_idx = len(after_lines)
        for i, line in enumerate(after_lines):
            if i > 0 and line.strip() and not line.startswith("- PR #"):
                end_idx = i
                break
        tail = "\n".join(after_lines[end_idx:])
        return before + block + tail.lstrip("\n")
    if "## Meta" in body:
        head, tail = body.split("## Meta", 1)
        return head.rstrip() + "\n\n## Meta\n\n" + block + tail.lstrip("\n")
    return body.rstrip() + "\n\n" + block


def append_coverage_into_body(body: str, records: list[dict]) -> str:
    if not records:
        return body
    existing = _coverage_prs_in_body(body)
    to_add = [record for record in records if int(record["pr"]) not in existing]
    if not to_add:
        return body
    if "**Evidence coverage**" not in body:
        return merge_coverage_into_body(body, to_add)
    lines = body.splitlines()
    insert_at = len(lines)
    for i, line in enumerate(lines):
        if line.strip() == "**Evidence coverage**":
            insert_at = i + 1
            while insert_at < len(lines) and (
                lines[insert_at].strip() == "" or lines[insert_at].startswith("- PR #")
            ):
                insert_at += 1
            break
    new_lines = [render_line(record) for record in sorted(to_add, key=lambda item: int(item["pr"]))]
    return "\n".join(lines[:insert_at] + new_lines + lines[insert_at:])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input",
        nargs="?",
        help="daily-retro.json path (default: stdin JSON)",
    )
    parser.add_argument(
        "--field",
        default="pr_evidence_coverage",
        help="JSON array field to render (default: pr_evidence_coverage)",
    )
    args = parser.parse_args()

    if args.input:
        data = json.loads(Path(args.input).read_text(encoding="utf-8"))
    else:
        data = json.load(sys.stdin)

    records = data.get(args.field) or []
    if not isinstance(records, list):
        print(f"{args.field} must be an array", file=sys.stderr)
        return 1

    block = render_block(records)
    if block:
        sys.stdout.write(block)
    return 0


if __name__ == "__main__":
    sys.exit(main())
