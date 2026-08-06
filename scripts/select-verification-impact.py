#!/usr/bin/env python3

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

SELECTOR_PATH = "scripts/select-verification-impact.py"
MANIFEST_PATH = ".config/verification-impact.json"
REQUIRED_MAPPING_KEYS = {"patterns", "bats", "checks"}
ALLOWED_MAPPING_KEYS = REQUIRED_MAPPING_KEYS | {"evidence"}


def fail(message: str) -> None:
    print(f"verification impact: {message}", file=sys.stderr)
    raise SystemExit(2)


def valid_relative(value: str) -> bool:
    path = PurePosixPath(value)
    return bool(value) and not path.is_absolute() and ".." not in path.parts and "\\" not in value


def proves_mapping(text: str, patterns: list[str]) -> bool:
    raw_tokens = set(re.findall(r"[A-Za-z0-9_./*-]+", text))
    tokens = raw_tokens | {token.rstrip(".-/") for token in raw_tokens}
    tokens |= {re.sub(r"^[A-Z][A-Z0-9_]*/", "", token) for token in tokens}
    return any(
        fnmatch.fnmatchcase(token, pattern)
        for pattern in patterns
        for token in tokens
        if token and not any(character in token for character in "*?[")
    )


def load_manifest(repo: Path) -> dict:
    try:
        manifest = json.loads((repo / MANIFEST_PATH).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid manifest: {error}")
    if set(manifest) != {"version", "fullPatterns", "mappings"} or manifest["version"] != 1:
        fail("invalid manifest structure or version")
    if not isinstance(manifest["fullPatterns"], list) or not isinstance(manifest["mappings"], list):
        fail("manifest patterns and mappings must be arrays")

    for pattern in manifest["fullPatterns"]:
        if not isinstance(pattern, str) or not valid_relative(pattern):
            fail(f"invalid full pattern: {pattern!r}")
    for mapping in manifest["mappings"]:
        if (
            not isinstance(mapping, dict)
            or not REQUIRED_MAPPING_KEYS.issubset(mapping)
            or not set(mapping).issubset(ALLOWED_MAPPING_KEYS)
        ):
            fail("mapping has unsupported or missing fields")
        if not mapping["patterns"] or not mapping["bats"] and not mapping["checks"]:
            fail("mapping must contain patterns and consumers")
        for pattern in mapping["patterns"]:
            if not isinstance(pattern, str) or not valid_relative(pattern):
                fail(f"invalid mapping pattern: {pattern!r}")
        consumers: list[str] = []
        for kind, prefix, suffix in (("bats", "scripts/tests/", ".bats"), ("checks", "scripts/checks/", ".sh")):
            if not isinstance(mapping[kind], list):
                fail(f"mapping {kind} must be an array")
            for consumer in mapping[kind]:
                if not isinstance(consumer, str) or not consumer.startswith(prefix) or not consumer.endswith(suffix):
                    fail(f"invalid {kind} consumer: {consumer!r}")
                if not (repo / consumer).is_file():
                    fail(f"missing consumer: {consumer}")
                consumers.append(consumer)

        evidence = mapping.get("evidence", {})
        if not isinstance(evidence, dict) or not set(evidence).issubset(consumers):
            fail("mapping evidence must name only declared consumers")
        for consumer in consumers:
            consumer_text = (repo / consumer).read_text(encoding="utf-8")
            if proves_mapping(consumer_text, mapping["patterns"]):
                continue
            evidence_path = evidence.get(consumer)
            if not isinstance(evidence_path, str) or not valid_relative(evidence_path):
                fail(f"unproven mapping: {consumer}; reference a mapped path or declare an evidence file")
            evidence_file = repo / evidence_path
            if not evidence_file.is_file():
                fail(f"missing mapping evidence: {evidence_path}")
            evidence_text = evidence_file.read_text(encoding="utf-8")
            if evidence_path not in consumer_text or not proves_mapping(evidence_text, mapping["patterns"]):
                fail(f"unproven mapping: {consumer} via {evidence_path}")
    return manifest


def changed_paths(args: argparse.Namespace, repo: Path) -> list[str]:
    paths = list(args.changed_path)
    if args.changed_paths_file:
        paths.extend(Path(args.changed_paths_file).read_text(encoding="utf-8").splitlines())
    if args.base or args.head:
        if not args.base or not args.head:
            fail("--base and --head must be provided together")
        result = subprocess.run(
            ["git", "diff", "--name-only", "--diff-filter=ACMRD", args.base, args.head, "--"],
            cwd=repo,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode:
            fail(f"git diff failed: {result.stderr.strip()}")
        paths.extend(result.stdout.splitlines())
    normalized = sorted({path.strip() for path in paths if path.strip()})
    for path in normalized:
        if not valid_relative(path):
            fail(f"invalid changed path: {path!r}")
    return normalized


def matches(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def build_plan(repo: Path, manifest: dict, paths: list[str], force_full: str | None) -> dict:
    bats: set[str] = set()
    checks: set[str] = set()
    reasons: set[str] = set()
    if force_full:
        reasons.add(force_full)
    if not paths:
        reasons.add("no-changed-paths")

    for path in paths:
        if path in {SELECTOR_PATH, MANIFEST_PATH} or matches(path, manifest["fullPatterns"]):
            reasons.add(f"shared-or-selection-infrastructure:{path}")
            continue
        if path.startswith("scripts/tests/") and path.endswith(".bats"):
            if (repo / path).is_file():
                bats.add(path)
            else:
                reasons.add(f"deleted-consumer:{path}")
            continue
        if path.startswith("scripts/checks/") and path.endswith(".sh"):
            if (repo / path).is_file():
                checks.add(path)
            else:
                reasons.add(f"deleted-consumer:{path}")
            continue
        matched = False
        for mapping in manifest["mappings"]:
            if matches(path, mapping["patterns"]):
                matched = True
                bats.update(mapping["bats"])
                checks.update(mapping["checks"])
        if not matched:
            reasons.add(f"unmapped:{path}")

    if not reasons and not bats and not checks:
        reasons.add("zero-consumers")
    mode = "full" if reasons else "selected"
    return {
        "version": 1,
        "mode": mode,
        "changedPaths": paths,
        "bats": [] if mode == "full" else sorted(bats),
        "checks": [] if mode == "full" else sorted(checks),
        "fallbackReasons": sorted(reasons),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--base")
    parser.add_argument("--head")
    parser.add_argument("--changed-path", action="append", default=[])
    parser.add_argument("--changed-paths-file")
    parser.add_argument("--force-full")
    parser.add_argument("--output")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    plan = build_plan(repo, load_manifest(repo), changed_paths(args, repo), args.force_full)
    rendered = json.dumps(plan, indent=2, sort_keys=True) + "\n"
    if args.output:
        Path(args.output).write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
