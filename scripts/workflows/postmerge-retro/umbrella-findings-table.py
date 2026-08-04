#!/usr/bin/env python3
"""Umbrella issue findings table format and legacy header migration."""
from __future__ import annotations

import re

FINDINGS_HEADER = (
    "| PR | Category | Key | Impact | Magnitude | trigger_likelihood | Scope | "
    "Reversibility | fix_cost | Confidence | Uncertainty | regression_guard | "
    "Band | Finding | Suggested fix |"
)
FINDINGS_SEPARATOR = "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"

LEGACY_HEADER_PATTERNS = (
    re.compile(
        r"^\|\s*PR\s*\|\s*Category\s*\|\s*Dedupe key\s*\|\s*Severity\s*\|",
        re.IGNORECASE,
    ),
    re.compile(
        r"^\|\s*PR\s*\|\s*Category\s*\|\s*Key\s*\|\s*Impact\s*\|\s*Trigger\s*\|\s*Band\s*\|",
        re.IGNORECASE,
    ),
    re.compile(
        r"^\|\s*PR\s*\|\s*Category\s*\|\s*Key\s*\|\s*Impact\s*\|\s*trigger_likelihood\s*\|\s*Band\s*\|",
        re.IGNORECASE,
    ),
    re.compile(
        r"^\|\s*PR\s*\|\s*Category\s*\|\s*Key\s*\|\s*Impact\s*\|\s*trigger_likelihood\s*\|\s*fix_cost\s*\|",
        re.IGNORECASE,
    ),
)


def format_guard(val) -> str:
    if val is True:
        return "true"
    if val is False:
        return "false"
    return str(val or "false")


def format_row(finding: dict, *, suggested_fix: str) -> str:
    title = str(finding.get("title", "")).replace("|", "/")
    suggested = suggested_fix.replace("|", "/")
    uncertainty = str(finding.get("uncertainty", "")).replace("|", "/")
    return (
        f"| #{finding['pr']} | {finding['category']} | `{finding['dedupe_key']}` | "
        f"{finding.get('impact', '')} | {finding.get('impact_magnitude', '')} | "
        f"{finding.get('trigger_likelihood', '')} | {finding.get('affected_scope', '')} | "
        f"{finding.get('reversibility', '')} | {finding.get('fix_cost', '')} | "
        f"{finding.get('confidence', '')} | {uncertainty} | "
        f"{format_guard(finding.get('regression_guard'))} | "
        f"{finding.get('priority_band', '')} | {title} | {suggested} |"
    )


def is_legacy_header(line: str) -> bool:
    stripped = line.strip()
    if stripped == FINDINGS_HEADER:
        return False
    return any(pat.match(stripped) for pat in LEGACY_HEADER_PATTERNS)


def migrate_findings_table(body: str) -> tuple[str, bool]:
    """Upgrade legacy findings table header to current triage columns."""
    lines = body.splitlines()
    out: list[str] = []
    migrated = False
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip() == "## Findings":
            out.append(line)
            i += 1
            while i < len(lines) and not lines[i].strip():
                out.append(lines[i])
                i += 1
            if i < len(lines) and is_legacy_header(lines[i]):
                out.append(FINDINGS_HEADER)
                migrated = True
                i += 1
                if i < len(lines) and re.match(r"^\|\s*[-:]+\s*\|", lines[i].strip()):
                    out.append(FINDINGS_SEPARATOR)
                    i += 1
                else:
                    out.append(FINDINGS_SEPARATOR)
                continue
            if i < len(lines) and lines[i].strip() == FINDINGS_HEADER:
                out.append(lines[i])
                i += 1
                if i < len(lines) and re.match(r"^\|\s*[-:]+\s*\|", lines[i].strip()):
                    out.append(lines[i])
                    i += 1
                continue
        out.append(line)
        i += 1
    return "\n".join(out), migrated
