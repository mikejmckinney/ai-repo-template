#!/usr/bin/env python3
"""Shared post-collect evidence coverage pre-check for post-merge retro."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

DEFAULT_DIFF_LIMIT = 300_000
DEFAULT_HEAD_FILE_CAP = 12_000
DEFAULT_HEAD_TOTAL_CAP = 120_000

EVIDENCE_ROUTES = (
    "bounded",
    "full-evidence-cursor",
    "full-evidence-antigravity",
    "bounded-fallback",
)


def _parse_positive_int(name: str, default: int, raw: str | None) -> int:
    if raw is None or raw == "":
        return default
    try:
        val = int(raw, 10)
    except ValueError:
        print(f"::warning::Invalid {name}={raw!r}; using default {default}", file=sys.stderr)
        return default
    if val <= 0:
        print(f"::warning::Invalid {name}={raw!r}; using default {default}", file=sys.stderr)
        return default
    return val


def _truthy_env(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _resolve_provider() -> str:
    want = os.environ.get("POSTMERGE_RETRO_PROVIDER") or os.environ.get(
        "ADVISORY_REVIEW_PROVIDER", "auto"
    )
    if want == "antigravity":
        want = "auto"
    has_cursor = bool(os.environ.get("CURSOR_API_KEY"))
    has_gemini = bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"))
    if want == "cursor":
        return "cursor"
    if want == "gemini":
        return "gemini"
    if want == "auto":
        if has_cursor:
            return "cursor"
        if has_gemini:
            return "gemini"
        return "unknown"
    return want


def _antigravity_available() -> bool:
    if not _truthy_env("ADVISORY_ANTIGRAVITY_ENABLED", default=False):
        return False
    return bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"))


def _resolve_evidence_route(
    *,
    would_truncate: bool,
    adaptive_enabled: bool,
    provider: str,
    cursor_available: bool,
    antigravity_available: bool,
    antigravity_on_truncate: bool,
) -> str:
    if not would_truncate:
        return "bounded"
    if not adaptive_enabled:
        return "bounded"
    if provider == "cursor" and cursor_available:
        return "full-evidence-cursor"
    if (
        provider == "gemini"
        and antigravity_available
        and antigravity_on_truncate
    ):
        return "full-evidence-antigravity"
    return "bounded-fallback"


def _simulate_head_coverage(
    repo_root: Path,
    changed_files_path: Path,
    *,
    head_file_cap: int,
    head_total_cap: int,
) -> tuple[int, int, list[str], bool]:
    if not changed_files_path.is_file():
        return 0, 0, [], False

    head_included = 0
    head_total = 0
    omitted_paths: list[str] = []
    head_truncated = False

    for raw in changed_files_path.read_text(encoding="utf-8").splitlines():
        rel = raw.strip()
        if not rel:
            continue
        target = repo_root / rel
        if not target.is_file():
            continue
        size = target.stat().st_size
        head_total += size

        if head_included >= head_total_cap:
            head_truncated = True
            omitted_paths.append(rel)
            continue

        take = min(size, head_file_cap)
        if head_included + take > head_total_cap:
            take = head_total_cap - head_included
        if take <= 0:
            head_truncated = True
            omitted_paths.append(rel)
            continue

        head_included += take
        if take < size:
            head_truncated = True
            omitted_paths.append(rel)

        if head_included >= head_total_cap:
            head_truncated = True

    return head_included, head_total, omitted_paths, head_truncated


def compute_coverage(
    evidence_dir: Path,
    *,
    repo_root: Path,
    pr: int,
    diff_limit: int,
    head_file_cap: int,
    head_total_cap: int,
) -> dict:
    diff_path = evidence_dir / "diff.patch"
    changed_files_path = evidence_dir / "changed-files.txt"

    full_diff_bytes = diff_path.stat().st_size if diff_path.is_file() else 0
    diff_truncated = full_diff_bytes > diff_limit
    diff_included = min(full_diff_bytes, diff_limit)

    head_included, head_total, omitted_paths, head_truncated = _simulate_head_coverage(
        repo_root,
        changed_files_path,
        head_file_cap=head_file_cap,
        head_total_cap=head_total_cap,
    )

    would_truncate = diff_truncated or head_truncated

    cursor_available = bool(os.environ.get("CURSOR_API_KEY"))
    antigravity_available = _antigravity_available()
    provider = _resolve_provider()
    adaptive_enabled = _truthy_env("POSTMERGE_RETRO_ADAPTIVE_EVIDENCE", default=False)
    antigravity_on_truncate = _truthy_env("POSTMERGE_RETRO_ANTIGRAVITY_ON_TRUNCATE", default=True)

    routing_context = {
        "adaptive_enabled": adaptive_enabled,
        "provider_resolved": provider,
        "cursor_available": cursor_available,
        "antigravity_available": antigravity_available,
        "antigravity_on_truncate": antigravity_on_truncate,
    }

    evidence_route = _resolve_evidence_route(
        would_truncate=would_truncate,
        adaptive_enabled=adaptive_enabled,
        provider=provider,
        cursor_available=cursor_available,
        antigravity_available=antigravity_available,
        antigravity_on_truncate=antigravity_on_truncate,
    )

    return {
        "pr": pr,
        "diff_included": diff_included,
        "diff_total": full_diff_bytes,
        "head_included": head_included,
        "head_total": head_total,
        "would_truncate": would_truncate,
        "diff_truncated": diff_truncated,
        "head_truncated": head_truncated,
        "omitted_head_paths": omitted_paths,
        "evidence_route": evidence_route,
        "routing_context": routing_context,
    }


def emit_truncation_warnings(record: dict) -> None:
    pr = record["pr"]
    if record.get("diff_truncated"):
        print(
            f"::warning::Post-merge retro PR #{pr}: diff truncated "
            f"({record['diff_included']}/{record['diff_total']} bytes)",
            file=sys.stderr,
        )
    if record.get("head_truncated"):
        omitted = record.get("omitted_head_paths") or []
        omitted_note = ""
        if omitted:
            preview = ", ".join(omitted[:5])
            if len(omitted) > 5:
                preview += f", … (+{len(omitted) - 5} more)"
            omitted_note = f"; omitted HEAD paths: {preview}"
        print(
            f"::warning::Post-merge retro PR #{pr}: HEAD evidence truncated "
            f"({record['head_included']}/{record['head_total']} bytes{omitted_note})",
            file=sys.stderr,
        )
    if record.get("evidence_route") == "bounded-fallback":
        ctx = record.get("routing_context") or {}
        provider = ctx.get("provider_resolved", "unknown")
        reasons: list[str] = []
        if not ctx.get("adaptive_enabled"):
            reasons.append("adaptive disabled")
        elif provider == "cursor" and not ctx.get("cursor_available"):
            reasons.append("CURSOR_API_KEY unset")
        elif provider == "gemini":
            if not ctx.get("antigravity_available"):
                reasons.append("antigravity unavailable")
            elif not ctx.get("antigravity_on_truncate"):
                reasons.append("POSTMERGE_RETRO_ANTIGRAVITY_ON_TRUNCATE=false")
        elif provider == "unknown":
            reasons.append("no retro provider configured")
        reason_text = "; ".join(reasons) if reasons else "full-evidence path unavailable"
        print(
            f"::warning::Post-merge retro PR #{pr}: adaptive routing fell back to bounded "
            f"truncated pass ({reason_text})",
            file=sys.stderr,
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence_dir", type=Path, help="Collector output directory")
    parser.add_argument("--pr", type=int, required=True, help="PR number")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Write evidence-coverage.json (default: stdout JSON)",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        help="Repository root for HEAD simulation (default: auto-detect)",
    )
    parser.add_argument(
        "--diff-limit",
        type=int,
        default=None,
        help=f"Diff byte cap (default: POSTMERGE_RETRO_DIFF_LIMIT or {DEFAULT_DIFF_LIMIT})",
    )
    parser.add_argument(
        "--head-file-cap",
        type=int,
        default=None,
        help=f"Per-file HEAD cap (default: {DEFAULT_HEAD_FILE_CAP})",
    )
    parser.add_argument(
        "--head-total-cap",
        type=int,
        default=None,
        help=f"Total HEAD cap (default: {DEFAULT_HEAD_TOTAL_CAP})",
    )
    parser.add_argument(
        "--warn",
        action="store_true",
        help="Emit ::warning:: lines when truncation is predicted",
    )
    args = parser.parse_args()

    evidence_dir = args.evidence_dir
    if not evidence_dir.is_dir():
        print(f"Evidence directory not found: {evidence_dir}", file=sys.stderr)
        return 1

    repo_root = args.repo_root
    if repo_root is None:
        repo_root = Path(__file__).resolve().parents[3]
    repo_root = repo_root.resolve()

    diff_limit = args.diff_limit
    if diff_limit is None:
        diff_limit = _parse_positive_int(
            "POSTMERGE_RETRO_DIFF_LIMIT",
            DEFAULT_DIFF_LIMIT,
            os.environ.get("POSTMERGE_RETRO_DIFF_LIMIT"),
        )

    head_file_cap = args.head_file_cap or DEFAULT_HEAD_FILE_CAP
    head_total_cap = args.head_total_cap or DEFAULT_HEAD_TOTAL_CAP

    record = compute_coverage(
        evidence_dir,
        repo_root=repo_root,
        pr=args.pr,
        diff_limit=diff_limit,
        head_file_cap=head_file_cap,
        head_total_cap=head_total_cap,
    )

    if args.warn and record["would_truncate"]:
        emit_truncation_warnings(record)

    payload = json.dumps(record, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    else:
        sys.stdout.write(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
