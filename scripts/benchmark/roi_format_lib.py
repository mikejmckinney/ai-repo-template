"""Shared ROI formatting helpers for results.md sync scripts."""

from __future__ import annotations


def parse_cost(s: str) -> float | None:
    s = s.strip().replace("`", "")
    if not s or s.upper() == "N/A" or "$" not in s:
        return None
    return float(s.replace("$", ""))


def fmt_cost(v: float) -> str:
    return f"`${v:.6f}`"


def fmt_roi(v: float) -> str:
    return f"`{v:.2f}`"


def fmt_delta(v: float) -> str:
    if abs(v) < 0.005:
        return "0"
    sign = "+" if v > 0 else ""
    return f"{sign}{v:.2f}"


def parse_row(line: str) -> list[str]:
    return [p.strip() for p in line.strip("|").split("|")]


def parse_pipeline_tail(parts: list[str]) -> tuple[str, str, str, str, str]:
    """Return wall, diff, cost_s, roi_s, summary from a pipeline results row."""
    wall = parts[15] if len(parts) > 15 else ""
    diff = parts[16] if len(parts) > 16 else ""
    summary = parts[-1]
    cost_s, roi_s = "N/A", "N/A"

    def _is_na_cost(cell: str) -> bool:
        token = cell.strip().replace("`", "").upper()
        return token in ("", "N", "N/A", "NA")

    if len(parts) >= 18 and _is_na_cost(parts[17]):
        summary = parts[19] if len(parts) > 19 else parts[-1]
        return wall, diff, "N/A", "N/A", summary

    if len(parts) >= 20:
        return wall, diff, parts[17], parts[18], parts[19]
    if len(parts) >= 19 and "/" not in parts[17]:
        cost_token = parts[17].strip().replace("`", "").upper()
        roi_token = parts[18].strip().replace("`", "").upper() if len(parts) > 18 else ""
        # Malformed `N | N/A` rows split cost across columns (missing closing backtick).
        if cost_token in ("N", "N/A", "NA") or roi_token in ("N/A", "NA"):
            summary = parts[19] if len(parts) > 19 else parts[-1]
            return wall, diff, "N/A", "N/A", summary
        # Already split Cost USD | ROI, or cost-only N/A row
        if parts[18].startswith("`") or parts[18].replace(".", "", 1).isdigit():
            return wall, diff, parts[17], parts[18], parts[-1]
        return wall, diff, parts[17], "N/A", parts[18]
    if len(parts) >= 18:
        cost_cell = parts[17].strip()
        if cost_cell in ("N/A", "`N/A`") or cost_cell.upper().startswith("N/A"):
            return wall, diff, "N/A", "N/A", parts[18] if len(parts) > 18 else parts[-1]
        if cost_cell.startswith("`N") and "N/A" in cost_cell:
            return wall, diff, "N/A", "N/A", parts[18] if len(parts) > 18 else parts[-1]
        if "/" in parts[17] and "$" in parts[17].split("/", 1)[0]:
            cost, roi = parse_cost_roi_cell(parts[17])
            cost_s = parts[17].split("/")[0].strip()
            roi_s = f"`{roi:.2f}`" if roi is not None else "N/A"
            summary = parts[18] if len(parts) > 18 else parts[-1]
            return wall, diff, cost_s, roi_s, summary
    return wall, diff, cost_s, roi_s, summary


def parse_cost_roi_cell(cell: str) -> tuple[float | None, float | None]:
    """Parse `$0.312429` / `278.46` combined cell."""
    if "/" not in cell:
        cost = parse_cost(cell)
        return cost, None
    left, right = [p.strip() for p in cell.split("/", 1)]
    cost = parse_cost(left)
    roi_s = right.strip().replace("`", "")
    roi = None
    if roi_s and roi_s.upper() != "N/A":
        try:
            roi = float(roi_s)
        except ValueError:
            roi = None
    return cost, roi
