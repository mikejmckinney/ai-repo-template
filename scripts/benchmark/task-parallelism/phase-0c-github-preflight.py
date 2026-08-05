#!/usr/bin/env python3
"""Exercise disposable GitHub state against the Phase 0C canonical ledger."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

from phase_0c_gate import canonical_bytes
from phase_0c_transport import GitHubCommentAdapter, github_event_body


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def gh_api(method: str, endpoint: str, payload: dict[str, Any] | None = None) -> Any:
    command = ["gh", "api", "--method", method, endpoint]
    encoded = None
    if payload is not None:
        command.extend(["--input", "-"])
        encoded = json.dumps(payload)
    completed = subprocess.run(
        command,
        input=encoded,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"GitHub API {method} {endpoint} failed: {detail}")
    return json.loads(completed.stdout) if completed.stdout.strip() else None


def close_fixture_state(
    repo: str, issue_number: int | None, pull_number: int | None, branch: str
) -> list[str]:
    errors = []
    if pull_number is not None:
        try:
            gh_api("PATCH", f"repos/{repo}/pulls/{pull_number}", {"state": "closed"})
        except RuntimeError as error:
            errors.append(str(error))
    if issue_number is not None:
        try:
            gh_api(
                "PATCH",
                f"repos/{repo}/issues/{issue_number}",
                {"state": "closed", "state_reason": "not_planned"},
            )
        except RuntimeError as error:
            errors.append(str(error))
    try:
        gh_api("DELETE", f"repos/{repo}/git/refs/heads/{branch}")
    except RuntimeError as error:
        if "Reference does not exist" not in str(error):
            errors.append(str(error))
    return errors


def run_local_a2a_preflight(manifest: Path, output: Path) -> dict[str, Any]:
    completed = subprocess.run(
        [
            sys.executable,
            str(Path(__file__).with_name("phase-0c-preflight.py")),
            "--manifest",
            str(manifest),
            "--output",
            str(output),
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"local A2A preflight failed: {detail}")
    return load_json(output)


def validate_report(report: dict[str, Any], schema_path: Path) -> None:
    errors = sorted(
        Draft202012Validator(load_json(schema_path)).iter_errors(report),
        key=lambda error: list(error.path),
    )
    if errors:
        raise ValueError(f"{schema_path.name}: {errors[0].message}")


def execute(args: argparse.Namespace) -> dict[str, Any]:
    manifest_path = args.manifest.resolve()
    namespace = manifest_path.parent
    manifest = load_json(manifest_path)
    fixture = load_json(namespace / manifest["canonical_event_fixture"]["path"])
    run_id = f"{uuid.uuid4().hex[:12]}"
    branch = f"phase-0c-preflight/{run_id}"
    issue_number = None
    pull_number = None
    failure: Exception | None = None
    result: dict[str, Any] | None = None

    with tempfile.TemporaryDirectory(prefix="phase-0c-github-") as temporary_dir:
        a2a_output = Path(temporary_dir) / "a2a-preflight.json"
        a2a_report = run_local_a2a_preflight(manifest_path, a2a_output)
        try:
            issue = gh_api(
                "POST",
                f"repos/{args.repo}/issues",
                {
                    "title": f"[DISPOSABLE] Phase 0C GitHub adapter preflight {run_id}",
                    "body": (
                        "Temporary no-spend transport fixture for issue #581. "
                        "Automation closes this record after validation."
                    ),
                },
            )
            issue_number = issue["number"]
            gh_api(
                "POST",
                f"repos/{args.repo}/git/refs",
                {"ref": f"refs/heads/{branch}", "sha": args.base_sha},
            )
            marker_path = (
                ".context/benchmarks/model-roi/task-parallelism/phase-0c-transport/"
                f"live-fixtures/{run_id}.json"
            )
            marker = canonical_bytes(
                {
                    "schema_version": "task-parallelism-phase-0c-live-fixture.v1",
                    "run_id": run_id,
                    "issue_number": issue_number,
                }
            )
            commit = gh_api(
                "PUT",
                f"repos/{args.repo}/contents/{marker_path}",
                {
                    "message": f"test: add disposable Phase 0C fixture {run_id}",
                    "content": base64.b64encode(marker).decode("ascii"),
                    "branch": branch,
                },
            )
            pull = gh_api(
                "POST",
                f"repos/{args.repo}/pulls",
                {
                    "title": f"[DISPOSABLE] Phase 0C GitHub adapter {run_id}",
                    "head": branch,
                    "base": args.base_ref,
                    "body": f"Temporary no-spend fixture for issue #581 and issue #{issue_number}.",
                    "draft": True,
                },
            )
            pull_number = pull["number"]
            for event in fixture["events"]:
                gh_api(
                    "POST",
                    f"repos/{args.repo}/issues/{issue_number}/comments",
                    {"body": github_event_body(event)},
                )
            comments = gh_api(
                "GET", f"repos/{args.repo}/issues/{issue_number}/comments?per_page=100"
            )
            github_adapter = GitHubCommentAdapter(comments)
            github_ledger, github_suppressed = github_adapter.receive()
            if github_adapter.marked_count != len(fixture["events"]):
                raise ValueError("GitHub marked event count differs from posted fixture")
            if canonical_bytes(github_ledger) != canonical_bytes(a2a_report["canonical_ledger"]):
                raise ValueError("GitHub and A2A canonical ledgers differ")
            result = {
                "schema_version": "task-parallelism-phase-0c-github-preflight.v1",
                "status": "pass",
                "repository": args.repo,
                "base_ref": args.base_ref,
                "base_sha": args.base_sha,
                "candidate_processes_started": 0,
                "paid_execution": "blocked-pending-explicit-approval",
                "github": {
                    "issue_number": issue_number,
                    "issue_url": issue["html_url"],
                    "comments_written": len(fixture["events"]),
                    "pull_number": pull_number,
                    "pull_url": pull["html_url"],
                    "branch": branch,
                    "fixture_commit_sha": commit["commit"]["sha"],
                    "issue_closed": True,
                    "pull_closed": True,
                    "branch_deleted": True,
                },
                "a2a_preflight_sha256": hashlib.sha256(a2a_output.read_bytes()).hexdigest(),
                "canonical_ledgers_equivalent": True,
                "duplicate_events_suppressed": github_suppressed,
                "canonical_ledger": github_ledger,
            }
        except Exception as error:
            failure = error
        cleanup_errors = close_fixture_state(
            args.repo, issue_number, pull_number, branch
        )
        if failure is not None:
            if cleanup_errors:
                raise RuntimeError(
                    f"{failure}; cleanup also failed: {'; '.join(cleanup_errors)}"
                ) from failure
            raise failure
        if cleanup_errors:
            raise RuntimeError(f"GitHub fixture cleanup failed: {'; '.join(cleanup_errors)}")

    if result is None:
        raise RuntimeError("GitHub preflight produced no result")
    validate_report(result, namespace / "github-preflight.schema.json")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--base-ref", required=True)
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if not args.apply:
        print("live GitHub preflight requires --apply; no repository state changed")
        return 2
    if not re.fullmatch(r"[0-9a-f]{40}", args.base_sha):
        raise ValueError("--base-sha must be a full lowercase commit SHA")
    if not re.fullmatch(r"[^/]+/[^/]+", args.repo):
        raise ValueError("--repo must use OWNER/REPOSITORY form")
    report = execute(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(canonical_bytes(report))
    print("Phase 0C live GitHub/A2A preflight passed; disposable state cleaned up")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
