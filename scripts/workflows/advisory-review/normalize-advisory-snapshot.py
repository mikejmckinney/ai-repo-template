#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path


MARKER = "<!-- ai-advisory-review:v1 -->"
MEMORY_PATTERN = re.compile(r"^<!-- ai-advisory-memory:v1 .* -->\n?", re.MULTILINE)
FINDINGS_PATTERN = re.compile(
    r"(### Findings to consider\s*\n\n)(.*?)(?=\n### |\Z)",
    re.DOTALL,
)
NOT_BLOCKING_TEXT = (
    "These findings are optional input while implementation continues. "
    "CI and maintainer decisions remain authoritative."
)
SEVERITIES = {"info", "low", "medium", "high"}
LENSES = {
    "Outcome and scope",
    "Correctness",
    "Tests",
    "Security and privacy",
    "Compatibility",
    "Reliability and performance",
    "Maintainability",
    "Documentation and process truth",
    "Evidence and noise discipline",
}


def replace_line(body: str, prefix: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(prefix)}.*$", re.MULTILINE)
    if pattern.search(body):
        return pattern.sub(f"{prefix}{value}", body, count=1)
    title = "## Advisory Review Snapshot"
    if title not in body:
        body = f"{title}\n\n{body.lstrip()}"
    return body.replace(title, f"{title}\n\n{prefix}{value}", 1)


def normalize_findings(body: str) -> tuple[str, int]:
    match = FINDINGS_PATTERN.search(body)
    if not match:
        raise ValueError("malformed findings section: required heading is missing")

    section = match.group(2).strip()
    if section == "No findings identified at this head.":
        return body, 0
    rows = [line for line in section.splitlines() if line.strip().startswith("|")]
    non_rows = [line for line in section.splitlines() if line.strip() and not line.strip().startswith("|")]
    if non_rows:
        raise ValueError("malformed findings section: prose is not a finding table or the exact no-findings sentence")
    if len(rows) < 2:
        raise ValueError("malformed findings section: expected a canonical table or the exact no-findings sentence")
    finding_rows = [
        line
        for line in rows
        if not re.match(r"^\|\s*(?:ID|[-:]+)\s*\|", line.strip(), re.IGNORECASE)
    ]
    if finding_rows:
        parsed_rows = [
            [cell.strip() for cell in row.strip().strip("|").split("|")]
            for row in finding_rows
        ]
        legacy_placeholder = ["ADV-01", "…", "…", "…", "…", "…", "yes/no"]
        if parsed_rows == [legacy_placeholder]:
            finding_rows = []
        elif legacy_placeholder in parsed_rows:
            raise ValueError("malformed findings section: placeholder row is mixed with findings")
    if finding_rows:
        for row in finding_rows:
            cells = [cell.strip() for cell in row.strip().strip("|").split("|")]
            if (
                len(cells) != 7
                or not all(cells)
                or not re.fullmatch(r"ADV-\d{2}", cells[0])
                or cells[1] not in SEVERITIES
                or cells[2] not in LENSES
                or cells[6] not in {"yes", "no"}
                or "…" in row
            ):
                raise ValueError("malformed findings section: invalid finding row")
        return body, len(finding_rows)

    replacement = f"{match.group(1)}No findings identified at this head.\n"
    return f"{body[:match.start()]}{replacement}{body[match.end():]}", 0


def canonicalize_envelope(body: str, head: str, provider: str, model: str, coverage: str) -> str:
    match = FINDINGS_PATTERN.search(body)
    if not match:
        raise ValueError("malformed findings section: required heading is missing")

    expected_lines = {
        MARKER: 0,
        "## Advisory Review Snapshot": 0,
        "Head: ": 0,
        "Provider: ": 0,
        "Mode: ": 0,
        "Diff coverage: ": 0,
    }
    for line in body[: match.start()].splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        matched = False
        for expected in expected_lines:
            if stripped == expected or (expected.endswith(": ") and stripped.startswith(expected)):
                expected_lines[expected] += 1
                matched = True
                break
        if not matched:
            raise ValueError("malformed snapshot: substantive content outside canonical sections")
    if any(count != 1 for count in expected_lines.values()):
        raise ValueError("malformed snapshot: canonical header fields must appear exactly once")

    suffix = body[match.end() :].strip()
    expected_suffix = f"### Not blocking\n\n{NOT_BLOCKING_TEXT}"
    if suffix != expected_suffix:
        raise ValueError("malformed snapshot: invalid non-blocking section")

    findings = match.group(2).strip()
    return f"""{MARKER}

## Advisory Review Snapshot

Head: `{head}`
Provider: `{provider} / {model}`
Mode: advisory, non-blocking
Diff coverage: {coverage}

### Findings to consider

{findings}

### Not blocking

{NOT_BLOCKING_TEXT}"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--provider-metadata", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--review-basis", choices=("full", "incremental"), required=True)
    parser.add_argument("--diff-included", type=int, required=True)
    parser.add_argument("--diff-total", type=int, required=True)
    parser.add_argument("--truncated", choices=("yes", "no"), required=True)
    parser.add_argument("--changed-files", type=int, required=True)
    args = parser.parse_args()

    metadata = json.loads(Path(args.provider_metadata).read_text(encoding="utf-8"))
    provider = metadata.get("provider")
    model = metadata.get("model")
    if not isinstance(provider, str) or not provider or not isinstance(model, str) or not model:
        raise SystemExit("provider metadata requires non-empty provider and model")

    body = Path(args.input).read_text(encoding="utf-8")
    if MARKER in body:
        preamble, snapshot = body.split(MARKER, 1)
        if preamble.strip():
            raise SystemExit("malformed snapshot: substantive preamble before canonical marker")
        body = f"{MARKER}{snapshot}"
    body = MEMORY_PATTERN.sub("", body).strip()
    if MARKER not in body:
        body = f"{MARKER}\n\n{body}"
    body = replace_line(body, "Head: ", f"`{args.head}`")
    body = replace_line(body, "Provider: ", f"`{provider} / {model}`")
    body = replace_line(body, "Mode: ", "advisory, non-blocking")
    coverage = (
        f"`{args.diff_included}/{args.diff_total}` bytes, "
        f"truncated: `{args.truncated}`, basis: `{args.review_basis}`"
    )
    body = replace_line(body, "Diff coverage: ", coverage)
    try:
        body, finding_count = normalize_findings(body)
        body = canonicalize_envelope(body, args.head, provider, model, coverage)
    except ValueError as error:
        raise SystemExit(str(error)) from error

    summary = (
        f"Reviewed {args.changed_files} changed files using {args.review_basis} diff; "
        f"{finding_count} findings reported."
    )
    memory = {
        "base_sha": args.base,
        "reviewed_head": args.head,
        "provider": provider,
        "model": model,
        "summary": summary,
    }
    memory_line = f"<!-- ai-advisory-memory:v1 {json.dumps(memory, separators=(',', ':'))} -->"
    body = body.replace(MARKER, f"{MARKER}\n{memory_line}", 1)
    Path(args.output).write_text(f"{body.strip()}\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
