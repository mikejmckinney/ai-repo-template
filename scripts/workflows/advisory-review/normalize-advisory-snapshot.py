#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path


MARKER = "<!-- ai-advisory-review:v1 -->"
MEMORY_PATTERN = re.compile(r"^<!-- ai-advisory-memory:v1 .* -->\n?", re.MULTILINE)


def replace_line(body: str, prefix: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(prefix)}.*$", re.MULTILINE)
    if pattern.search(body):
        return pattern.sub(f"{prefix}{value}", body, count=1)
    title = "## Advisory Review Snapshot"
    if title not in body:
        body = f"{title}\n\n{body.lstrip()}"
    return body.replace(title, f"{title}\n\n{prefix}{value}", 1)


def normalize_findings(body: str) -> tuple[str, int]:
    pattern = re.compile(
        r"(### Findings to consider\s*\n\n)(.*?)(?=\n### |\Z)",
        re.DOTALL,
    )
    match = pattern.search(body)
    if not match:
        section = "### Findings to consider\n\nNo findings identified at this head.\n\n"
        not_blocking = "### Not blocking"
        if not_blocking in body:
            return body.replace(not_blocking, f"{section}{not_blocking}", 1), 0
        return f"{body.rstrip()}\n\n{section}", 0

    section = match.group(2).strip()
    rows = [line for line in section.splitlines() if line.strip().startswith("|")]
    finding_rows = [
        line
        for line in rows
        if not re.match(r"^\|\s*(?:ID|[-:]+)\s*\|", line.strip(), re.IGNORECASE)
    ]
    finding_rows = [line for line in finding_rows if "ADV-01 | …" not in line]
    if finding_rows:
        return body, len(finding_rows)

    replacement = f"{match.group(1)}No findings identified at this head.\n"
    return f"{body[:match.start()]}{replacement}{body[match.end():]}", 0


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
    body, finding_count = normalize_findings(body)

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
