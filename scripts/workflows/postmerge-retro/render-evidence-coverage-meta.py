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
    provenance = ctx.get("provenance") or {}
    requested_model = str(provenance.get("requested_model") or "unknown")
    observed_model = str(provenance.get("observed_model") or "unknown")
    antigravity = _bool_word(bool(ctx.get("antigravity_available")))

    truncated = bool(record.get("would_truncate"))
    diff_part = f"diff {diff_included}/{diff_total}"
    if route in ("full-evidence-opencode", "full-evidence-cursor", "full-evidence-antigravity"):
        diff_part += " (full-evidence)"
    elif truncated:
        diff_part += " (truncated)"

    parts = [
        f"PR #{pr} — {diff_part}",
        f"route: {route}",
        f"provider: {provider}",
        f"requested: {requested_model}",
        f"observed: {observed_model}",
    ]
    attempts = record.get("provider_attempts") or []
    if attempts:
        attempt_text = ", ".join(
            f"{item.get('provider', 'unknown')}:{item.get('status', 'unknown')}" for item in attempts
        )
        parts.append(f"attempts: {attempt_text}")
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


def _needs_truncation_warning(record: dict) -> bool:
    """Summary warns only when retro actually ran a truncated bounded pass."""
    if not record.get("would_truncate"):
        return False
    route = str(record.get("evidence_route") or "bounded")
    return route in ("bounded", "bounded-fallback")


def render_summary_callout(records: list[dict]) -> str:
    """High-visibility Summary callout when truncated bounded evidence was used."""
    truncated = [record for record in records if _needs_truncation_warning(record)]
    if not truncated:
        return ""

    lines = [
        "> [!WARNING]",
        "> **Evidence truncated** — retro used partial diff/HEAD excerpts for the PR(s) below. "
        "Findings may miss unseen changes. See **Evidence coverage** in Meta for full route context.",
        ">",
    ]
    for record in sorted(truncated, key=lambda item: int(item["pr"])):
        pr = int(record["pr"])
        diff_included = int(record["diff_included"])
        diff_total = int(record["diff_total"])
        route = str(record.get("evidence_route") or "bounded")
        line = f"> - **PR #{pr}** — diff {diff_included}/{diff_total} bytes; route: `{route}`"
        if route == "bounded-fallback":
            ctx = record.get("routing_context") or {}
            line += f"; fallback: {_fallback_reason(ctx)}"
        if record.get("head_truncated"):
            line += f"; HEAD {record['head_included']}/{record['head_total']} bytes"
        lines.append(line)
    lines.append("")
    return "\n".join(lines)


SUMMARY_START = "<!-- postmerge-retro:truncation-summary:start -->"
SUMMARY_END = "<!-- postmerge-retro:truncation-summary:end -->"


def _wrap_summary_callout(callout: str) -> str:
    if not callout.strip():
        return ""
    return "\n".join([SUMMARY_START, callout.rstrip(), SUMMARY_END, ""])


def merge_summary_into_body(body: str, records: list[dict]) -> str:
    wrapped = _wrap_summary_callout(render_summary_callout(records))
    if SUMMARY_START in body and SUMMARY_END in body:
        before, _, rest = body.partition(SUMMARY_START)
        _, _, after = rest.partition(SUMMARY_END)
        if wrapped:
            return before.rstrip() + "\n\n" + wrapped + after.lstrip("\n")
        return before.rstrip() + "\n" + after.lstrip("\n")

    if not wrapped:
        return body

    marker = f"**PRs in this update:**"
    if marker in body:
        lines = body.splitlines()
        out: list[str] = []
        inserted = False
        for i, line in enumerate(lines):
            out.append(line)
            if not inserted and line.strip().startswith(marker):
                out.append("")
                out.extend(wrapped.rstrip("\n").splitlines())
                inserted = True
        if inserted:
            return "\n".join(out) + ("\n" if body.endswith("\n") else "")
    return body.rstrip() + "\n\n" + wrapped


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
    body = merge_summary_into_body(body, records)
    if not records:
        return body
    if "**Evidence coverage**" not in body:
        return merge_coverage_into_body(body, records)

    lines = body.splitlines()
    heading_at = -1
    for i, line in enumerate(lines):
        if line.strip() == "**Evidence coverage**":
            heading_at = i
            break
    if heading_at < 0:
        return body

    section_end = heading_at + 1
    while section_end < len(lines) and (
        not lines[section_end].strip() or lines[section_end].startswith("- PR #")
    ):
        section_end += 1

    replacements = {int(record["pr"]): render_line(record) for record in records}
    rendered: list[str] = []
    seen: set[int] = set()
    for line in lines[heading_at + 1 : section_end]:
        if not line.startswith("- PR #"):
            continue
        try:
            pr = int(line.split("PR #", 1)[1].split("—", 1)[0].strip())
        except ValueError:
            rendered.append(line)
            continue
        rendered.append(replacements.get(pr, line))
        seen.add(pr)
    rendered.extend(replacements[pr] for pr in sorted(replacements) if pr not in seen)

    replacement_block = ["**Evidence coverage**", "", *rendered, ""]
    merged = "\n".join(lines[:heading_at] + replacement_block + lines[section_end:])
    return merged + ("\n" if body.endswith("\n") else "")


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
    parser.add_argument(
        "--section",
        choices=("meta", "summary", "all"),
        default="meta",
        help="Render Meta coverage block (default), Summary callout, or both",
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

    block = render_block(records) if args.section in ("meta", "all") else ""
    summary = render_summary_callout(records) if args.section in ("summary", "all") else ""
    if args.section == "summary":
        if summary:
            sys.stdout.write(_wrap_summary_callout(summary))
        return 0
    if block:
        sys.stdout.write(block)
    if summary and args.section == "all":
        sys.stdout.write(_wrap_summary_callout(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
