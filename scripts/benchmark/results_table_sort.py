"""Sort agent-roi-benchmark-results.md tables per documented rules."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from roi_format_lib import parse_cost_roi_cell, parse_row


@dataclass
class TableRule:
    heading_match: str
    sort_note: str
    sort_key: Callable[[list[str], list[str]], tuple]


def _alias_key(parts: list[str], _header: list[str]) -> tuple:
    return (parts[0].strip("`").lower(),)


def _canonical_key(parts: list[str], header: list[str]) -> tuple:
    idx = next((i for i, h in enumerate(header) if "Canonical /100" in h), None)
    if idx is None:
        idx = next((i for i, h in enumerate(header) if "Legacy /100" in h), 7)
    try:
        return (-int(parts[idx].strip("`")), parts[0])
    except (ValueError, IndexError):
        return (9999, parts[0])


def _roi_key(parts: list[str], header: list[str]) -> tuple:
    for label in ("Marginal ROI", "ROI", "Cost / ROI"):
        idx = next((i for i, h in enumerate(header) if label in h), None)
        if idx is None or idx >= len(parts):
            continue
        cell = parts[idx]
        if label == "Cost / ROI":
            _, roi = parse_cost_roi_cell(cell)
            if roi is not None:
                return (-roi, parts[0])
            return (9999, parts[0])
        try:
            return (-float(cell.strip("`")), parts[0])
        except ValueError:
            return (9999, parts[0])
    return (9999, parts[0])


def _platform_key(parts: list[str], _header: list[str]) -> tuple:
    return (parts[0].lower(),)


TABLE_RULES: list[TableRule] = [
    TableRule("## Class A: `opfit-281-class-a-premerge`", "Sorted by **Canonical /100** (desc).", _canonical_key),
    TableRule("### Class A Raw Telemetry", "Sorted by **Alias** (asc).", _alias_key),
    TableRule("### Class A Extended Run Notes", "Sorted by **Alias** (asc).", _alias_key),
    TableRule("## Class B: `opfit-326-class-b-premerge`", "Sorted by **Canonical /100** (desc).", _canonical_key),
    TableRule("### Class B Extended Run Notes", "Sorted by **Alias** (asc).", _alias_key),
    TableRule("### Class B Raw Telemetry", "Sorted by **Alias** (asc).", _alias_key),
    TableRule("## Sealed Alias Mapping", "Sorted by **Alias** (asc).", _alias_key),
    TableRule("Cost source register", "Sorted by **Platform / rows** (asc).", _platform_key),
    TableRule("### Class A Marginal ROI", "Sorted by **Marginal ROI** (desc); non-numeric ROI last.", _roi_key),
    TableRule("### Class B Marginal ROI", "Sorted by **Marginal ROI** (desc); non-numeric ROI last.", _roi_key),
    TableRule("### Stage 1C Class A:", "Sorted by **Marginal ROI** (desc).", _roi_key),
    TableRule("### Stage 1C Class B:", "Sorted by **Marginal ROI** (desc).", _roi_key),
    TableRule("### Stage 1D Class A:", "Sorted by **Marginal ROI** (desc).", _roi_key),
    TableRule("### Stage 1D Class B:", "Sorted by **Marginal ROI** (desc).", _roi_key),
    TableRule("### Issue #376 Class A:", "Sorted by **ROI** (desc); `N/A` cost rows last.", _roi_key),
    TableRule("### Issue #376 Class B:", "Sorted by **ROI** (desc); `N/A` cost rows last.", _roi_key),
    TableRule("### Stage 1E Class A:", "Sorted by **ROI** (desc).", _roi_key),
    TableRule("### Stage 1E Class B:", "Sorted by **ROI** (desc).", _roi_key),
    TableRule("### Context-pack comparison", "Sorted by **mean ROI** (desc).", _roi_key),
]


def rule_for_line(line: str) -> TableRule | None:
    for rule in TABLE_RULES:
        if rule.heading_match in line:
            return rule
    return None


def pipeline_separator(header: list[str]) -> str:
    cells = []
    for h in header:
        h = h.strip()
        if h in {"Alias", "Platform / model", "Run", "Gates", "score_set_id", "Diff", "Summary", "Cost USD"}:
            cells.append("---")
        else:
            cells.append("---:")
    return "|" + "|".join(cells) + "|"


def sort_markdown_tables(lines: list[str]) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        rule = rule_for_line(line)
        if not rule:
            out.append(line)
            i += 1
            continue

        out.append(line)
        i += 1
        block: list[str] = []
        while i < len(lines):
            nxt = lines[i]
            if nxt.startswith("## ") or nxt.startswith("### "):
                if rule_for_line(nxt) and nxt != line:
                    break
            if nxt.startswith("## ") and not nxt.startswith("### "):
                break
            if rule_for_line(nxt) and nxt != line:
                break
            block.append(nxt)
            i += 1

        note = f"*Table sort: {rule.sort_note}*"
        cleaned: list[str] = []
        for b in block:
            if b.startswith("*Table sort:"):
                continue
            cleaned.append(b)

        insert_at = 0
        while insert_at < len(cleaned) and cleaned[insert_at].strip() == "":
            insert_at += 1
        while insert_at < len(cleaned) and not cleaned[insert_at].startswith("|"):
            insert_at += 1
        cleaned.insert(insert_at, note)
        if insert_at + 1 < len(cleaned) and cleaned[insert_at + 1].strip() != "":
            cleaned.insert(insert_at + 1, "")

        j = 0
        while j < len(cleaned):
            if not cleaned[j].startswith("|") or j + 1 >= len(cleaned):
                out.append(cleaned[j])
                j += 1
                continue
            header = parse_row(cleaned[j])
            if j + 1 < len(cleaned) and cleaned[j + 1].startswith("|---"):
                sep = cleaned[j + 1]
                if "Issue #376 Class" in line:
                    sep = pipeline_separator(header)
                out.append(cleaned[j])
                out.append(sep)
                j += 2
                rows = []
                while j < len(cleaned) and cleaned[j].startswith("|"):
                    rows.append(parse_row(cleaned[j]))
                    j += 1
                rows.sort(key=lambda p: rule.sort_key(p, header))
                for r in rows:
                    out.append("| " + " | ".join(r) + " |")
            else:
                out.append(cleaned[j])
                j += 1
    return out
