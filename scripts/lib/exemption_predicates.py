#!/usr/bin/env python3
"""scripts/lib/exemption_predicates.py

ADR-028 Exemption Predicate Validator -- DevOps implementation (issue #349).

Implements the four closed-taxonomy predicates from ADR-028 paragraphs A1-A4:
  - judge_decision       A1   -- comment-body header + allowlist check
  - label                A1p4 -- exemption label + applier exclusion (RC3)
  - operational_process  A3   -- path glob + grep fallback
  - adr_clause           A4   -- registry entry + expiry check

Self-check CLI:
  python3 scripts/lib/exemption_predicates.py --self-check

Individual predicate CLI (for use by bash check scripts):
  python3 scripts/lib/exemption_predicates.py judge-decision \
      --comment-body TEXT_OR_@FILE --runtime-identity LOGIN
  python3 scripts/lib/exemption_predicates.py label \
      --pr-labels LABEL,... --applier-login LOGIN \
      --exemption-labels LABEL,... --subagents-dispatched LOGIN,...
  python3 scripts/lib/exemption_predicates.py operational-process \
      --changed-paths PATH,... --pr-body TEXT_OR_@FILE
  python3 scripts/lib/exemption_predicates.py adr-clause \
      --clause-id ADR-NNN#slug [--now YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit("PyYAML is required: pip install PyYAML") from exc

# ---------------------------------------------------------------------------
# A2 header regex (load-bearing contract -- ADR-028 A1p3 + A2)
#
# Matches exactly:
#   ## Judge <em-dash> DECISION      (em-dash U+2014, one space each side)
#   <zero or more blank lines>
#   DECISION: APPROVE WITH EXEMPTION <em-dash> <non-empty reason>
#
# A hyphen-minus instead of an em-dash FAILS (RC2 closure).
# ---------------------------------------------------------------------------
_EM_DASH = "\u2014"
_JUDGE_HEADER_RE = re.compile(
    r"^## Judge " + _EM_DASH + r" DECISION[ \t]*\n"
    r"(\s*\n)*"
    r"DECISION:\s+APPROVE WITH EXEMPTION\s+" + _EM_DASH + r"\s+\S",
    re.MULTILINE,
)

# ---------------------------------------------------------------------------
# A3 operational_process glob table
#
# Source: ADR-028 A3 canonical set, extended by Architect plan AC12
# (Judge plan-gate APPROVED at comment 4490239202). Plan additions noted.
# ---------------------------------------------------------------------------
_OP_PROCESS_GLOBS: List[str] = [
    ".github/prompts/**",
    ".github/workflows/**",
    ".github/actions/**",                   # plan extension: JS payload (AC12)
    ".github/agents/**",
    ".github/ISSUE_TEMPLATE/**",
    ".github/pull_request_template.md",
    ".github/copilot-instructions.md",
    ".claude/agents/**",                    # plan extension: Claude overlay agents (AC12)
    ".context/rules/process_*.md",
    ".context/rules/agent_ownership.md",    # plan extension: not matched by process_*
    ".context/rules/domain_*.md",           # plan extension: domain rules
    ".context/rules/repo_*.md",             # plan extension: repo orchestration rules
    ".context/state/**",
    "scripts/**",
    "Makefile",
    "install.sh",
    "test.sh",
    ".pre-commit-config.yaml",
    ".pre-commit-config.yaml.template",
]

# A3 grep fallback phrases (case-sensitive substring match in PR body)
_OP_GREP_FALLBACK_PHRASES: List[str] = [
    "operational/process per ADR-014",
    "shared procedural prompt",
    "operational_process exemption",
    "exempt per ADR-014",
    "exempt per pr-resolve-all.md",
    "exempt per repo-onboarding.md",
    "exempt per expand-backlog-entry.md",
    "exempt per capture-postmortem.md",
    "exempt per mirror-postmortem.md",
]

# Default recognized exemption label names (RC3)
EXEMPTION_LABELS: List[str] = [
    "chore:no-plan",
    "smoke-test",
    "outcome-validated",
    "cap-override",
    "exempt-from-preflight",
    "exempt-from-plan-gate",
]

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _load_yaml_file(path: Path) -> Any:
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ValueError(f"{path}: YAML parse failed: {exc}") from exc


def _matches_any_glob(path_str: str, globs: List[str]) -> bool:
    """Return True if path_str matches any glob.

    Python fnmatch: * matches any characters including /, so ** also matches
    nested paths (**.txt matches dir/sub/file.txt). This is sufficient for the
    A3 glob table which uses trailing /** patterns.
    """
    path_str = path_str.replace("\\", "/")
    for g in globs:
        if fnmatch.fnmatch(path_str, g):
            return True
    return False


# ---------------------------------------------------------------------------
# Predicate 1: judge_decision  A1
# ---------------------------------------------------------------------------


def judge_decision(
    comment_body: str,
    runtime_identity: str,
    allowlist: Dict[str, Any],
) -> bool:
    """A1 judge_decision predicate.

    Returns True iff:
    - comment_body contains the A2 two-line header (em-dash, exact wording)
    - runtime_identity is in allowlist['allowlist'][].login
    - runtime_identity is NOT in allowlist['revoked'][].login

    Author-disjoint and subagents_dispatched exclusion (A1p4) must be
    enforced by the caller; this function validates the header surface (RC2)
    and allowlist membership (RC1 partial).
    """
    if not _JUDGE_HEADER_RE.search(comment_body):
        return False

    revoked = {e["login"] for e in allowlist.get("revoked", [])}
    if runtime_identity in revoked:
        return False

    allowed = {e["login"] for e in allowlist.get("allowlist", [])}
    return runtime_identity in allowed


# ---------------------------------------------------------------------------
# Predicate 2: label  A1p4 RC3
# ---------------------------------------------------------------------------


def label(
    pr_labels: List[str],
    label_appliers_by_label: List[str],
    exemption_labels: List[str],
    applier_login: str,
    enforce_appliers_config: Dict[str, Any],
) -> bool:
    """A1p4 RC3 label predicate.

    pr_labels: labels currently on the PR.
    label_appliers_by_label: list of logins excluded from being valid appliers
        (corresponds to parent_compliance.subagents_dispatched[].agent).
        Despite the parameter name (which mirrors the self-check calling
        convention), this is the set of disallowed applier identities.
    exemption_labels: recognized exemption label names.
    applier_login: the login that applied the matched exemption label.
    enforce_appliers_config: parsed exemption_label_appliers.yaml.

    Returns True iff:
    - PR carries at least one recognized exemption label
    - applier_login is NOT in label_appliers_by_label (always-on RC3 rule)
    - If enforce policy is enabled and label is in enforce_for_labels,
      applier_login must be in the enforce allowlist.
    """
    matched = [lbl for lbl in pr_labels if lbl in exemption_labels]
    if not matched:
        return False

    # Always-on RC3: applier must not be a dispatched subagent identity
    excluded = set(label_appliers_by_label)
    if applier_login in excluded:
        return False

    # Optional defense-in-depth enforce policy (disabled by default per ADR-028)
    policy = enforce_appliers_config.get("policy", {})
    if policy.get("enforce", False):
        enforce_for = policy.get("enforce_for_labels", [])
        allowed_appliers = {
            e["login"] for e in enforce_appliers_config.get("allowlist", [])
        }
        for ml in matched:
            if ml in enforce_for and applier_login not in allowed_appliers:
                return False

    return True


# ---------------------------------------------------------------------------
# Predicate 3: operational_process  A3
# ---------------------------------------------------------------------------


def operational_process(
    changed_paths: List[str],
    glob_table: List[str],
    grep_fallback_phrases: List[str],
    pr_body: str,
) -> bool:
    """A3 operational_process predicate.

    Returns True iff:
    - Every changed path matches at least one glob in glob_table (glob condition), OR
    - At least one grep_fallback_phrase appears in pr_body (grep fallback).

    An empty changed_paths list is rejected (no evidence of scope).
    The grep fallback issue cross-reference requirement (A3) is the caller's
    responsibility when invoking this function outside the self-check mode.
    """
    if not changed_paths:
        return False

    # Glob condition: ALL paths must match at least one glob
    if all(_matches_any_glob(p, glob_table) for p in changed_paths):
        return True

    # Grep fallback: any registered phrase in PR body
    for phrase in grep_fallback_phrases:
        if phrase in pr_body:
            return True

    return False


# ---------------------------------------------------------------------------
# Predicate 4: adr_clause  A4
# ---------------------------------------------------------------------------

_ADR_CLAUSE_RE = re.compile(r"^ADR-\d+#.+$")


def adr_clause(
    clause_id: str,
    registry: Dict[str, Any],
    now: date,
) -> bool:
    """A4 adr_clause predicate.

    Returns True iff:
    - clause_id matches ADR-NNN#<slug> format
    - clause_id appears in registry['entries'][] (active list)
    - clause_id is NOT in registry['expired'][]
    - The entry's expires_at is null or a future date relative to `now`
    """
    if not _ADR_CLAUSE_RE.match(clause_id):
        return False

    # Expired list takes precedence over active entries
    expired = {e["clause_id"] for e in registry.get("expired", [])}
    if clause_id in expired:
        return False

    # Find in active entries
    for entry in registry.get("entries", []):
        if entry["clause_id"] == clause_id:
            expires_at = entry.get("expires_at")
            if expires_at is None:
                return True
            # YAML may return a date object or a string
            if isinstance(expires_at, str):
                exp_date = date.fromisoformat(expires_at)
            elif isinstance(expires_at, date):
                exp_date = expires_at
            else:
                return False
            return now < exp_date

    # Not found in active entries
    return False


# ---------------------------------------------------------------------------
# Self-check: run all fixtures and report pass/fail
# ---------------------------------------------------------------------------


def _load_repo_registries(repo_root: Path) -> Dict[str, Any]:
    """Load the three live registry YAMLs from .context/state/."""
    return {
        "allowlist": _load_yaml_file(
            repo_root / ".context/state/judge_runtime_allowlist.yaml"
        ),
        "label_appliers": _load_yaml_file(
            repo_root / ".context/state/exemption_label_appliers.yaml"
        ),
        "adr_registry": _load_yaml_file(
            repo_root / ".context/state/adr_exemption_registry.yaml"
        ),
    }


def _run_fixture(
    fixture_path: Path,
    registries: Dict[str, Any],
) -> "tuple[bool, str]":
    """Run a single fixture file. Returns (passed, description_message)."""
    data = _load_yaml_file(fixture_path)
    kind = data.get("kind")
    inputs = data.get("inputs", {})
    expected = data.get("expected")

    if expected is None:
        return False, "missing 'expected' field in fixture"

    try:
        if kind == "judge_decision":
            allowlist = inputs.get("allowlist_override") or registries["allowlist"]
            result = judge_decision(
                comment_body=inputs["comment_body"],
                runtime_identity=inputs["runtime_identity"],
                allowlist=allowlist,
            )

        elif kind == "label":
            enforce_cfg = (
                inputs.get("enforce_config_override") or registries["label_appliers"]
            )
            result = label(
                pr_labels=inputs["pr_labels"],
                label_appliers_by_label=inputs.get("subagents_dispatched", []),
                exemption_labels=inputs.get("exemption_labels", EXEMPTION_LABELS),
                applier_login=inputs["applier_login"],
                enforce_appliers_config=enforce_cfg,
            )

        elif kind == "operational_process":
            result = operational_process(
                changed_paths=inputs["changed_paths"],
                glob_table=_OP_PROCESS_GLOBS,
                grep_fallback_phrases=_OP_GREP_FALLBACK_PHRASES,
                pr_body=inputs.get("pr_body", ""),
            )

        elif kind == "adr_clause":
            registry = inputs.get("registry_override") or registries["adr_registry"]
            now_str = inputs.get("now")
            now_date = date.fromisoformat(str(now_str)) if now_str else date.today()
            result = adr_clause(
                clause_id=inputs["clause_id"],
                registry=registry,
                now=now_date,
            )

        else:
            return False, f"unknown kind: {kind!r}"

    except (KeyError, TypeError, ValueError) as exc:
        return False, f"predicate error: {exc}"

    if result == expected:
        return True, f"result={result} == expected={expected}"
    return False, f"result={result} != expected={expected}"


def self_check(repo_root: Path) -> int:
    """Run all fixtures under scripts/tests/fixtures/exemptions/. Returns 0 on pass, 1 on fail."""
    fixture_root = repo_root / "scripts/tests/fixtures/exemptions"
    if not fixture_root.is_dir():
        print(f"FAIL: fixture directory not found: {fixture_root}", file=sys.stderr)
        return 1

    try:
        registries = _load_repo_registries(repo_root)
    except (OSError, ValueError) as exc:
        print(f"FAIL: could not load registries: {exc}", file=sys.stderr)
        return 1

    fixtures = sorted(fixture_root.rglob("*.yml"))
    if not fixtures:
        print(
            "FAIL: no fixtures found under scripts/tests/fixtures/exemptions/",
            file=sys.stderr,
        )
        return 1

    failures = 0
    for fx in fixtures:
        rel = fx.relative_to(repo_root)
        passed, msg = _run_fixture(fx, registries)
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {rel}: {msg}")
        if not passed:
            failures += 1

    total = len(fixtures)
    print(f"\n{total - failures}/{total} fixtures passed")
    return 0 if failures == 0 else 1


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="ADR-028 exemption predicate validator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--self-check",
        action="store_true",
        help="Run all fixtures and report pass/fail per fixture",
    )

    sub = p.add_subparsers(dest="command")

    # judge-decision
    jd = sub.add_parser("judge-decision", help="Validate A1 judge_decision predicate")
    jd.add_argument("--comment-body", required=True,
                    help="Comment body text or @filepath")
    jd.add_argument("--runtime-identity", required=True,
                    help="Comment author login")
    jd.add_argument("--allowlist-file",
                    default=".context/state/judge_runtime_allowlist.yaml",
                    help="Path to judge_runtime_allowlist.yaml")

    # label
    lb = sub.add_parser("label", help="Validate A1p4 RC3 label predicate")
    lb.add_argument("--pr-labels", required=True,
                    help="Comma-separated label names on the PR")
    lb.add_argument("--applier-login", required=True,
                    help="Login that applied the exemption label")
    lb.add_argument("--exemption-labels",
                    default=",".join(EXEMPTION_LABELS),
                    help="Comma-separated recognized exemption label names")
    lb.add_argument("--subagents-dispatched", default="",
                    help="Comma-separated subagent logins excluded from label application")
    lb.add_argument("--enforce-config-file",
                    default=".context/state/exemption_label_appliers.yaml",
                    help="Path to exemption_label_appliers.yaml")

    # operational-process
    op = sub.add_parser("operational-process",
                        help="Validate A3 operational_process predicate")
    op.add_argument("--changed-paths", required=True,
                    help="Comma-separated changed file paths")
    op.add_argument("--pr-body", default="",
                    help="PR body text or @filepath")

    # adr-clause
    ac = sub.add_parser("adr-clause", help="Validate A4 adr_clause predicate")
    ac.add_argument("--clause-id", required=True,
                    help="Clause identifier in ADR-NNN#slug format")
    ac.add_argument("--now",
                    help="Override today's date (YYYY-MM-DD)")
    ac.add_argument("--registry-file",
                    default=".context/state/adr_exemption_registry.yaml",
                    help="Path to adr_exemption_registry.yaml")

    return p


def _read_arg_or_file(value: str) -> str:
    """If value starts with @, read the named file; otherwise return as-is."""
    if value.startswith("@"):
        return Path(value[1:]).read_text(encoding="utf-8")
    return value


def main(argv: Optional[List[str]] = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    repo_root = Path(__file__).resolve().parents[2]

    if args.self_check:
        return self_check(repo_root)

    if not args.command:
        parser.print_help()
        return 1

    if args.command == "judge-decision":
        body = _read_arg_or_file(args.comment_body)
        al = _load_yaml_file(Path(args.allowlist_file))
        result = judge_decision(body, args.runtime_identity, al)
        print("true" if result else "false")
        return 0 if result else 1

    if args.command == "label":
        pr_labels = [x.strip() for x in args.pr_labels.split(",") if x.strip()]
        exemption = [x.strip() for x in args.exemption_labels.split(",") if x.strip()]
        subagents = [x.strip() for x in args.subagents_dispatched.split(",") if x.strip()]
        ec = _load_yaml_file(Path(args.enforce_config_file))
        result = label(pr_labels, subagents, exemption, args.applier_login, ec)
        print("true" if result else "false")
        return 0 if result else 1

    if args.command == "operational-process":
        paths = [x.strip() for x in args.changed_paths.split(",") if x.strip()]
        body = _read_arg_or_file(args.pr_body)
        result = operational_process(
            paths, _OP_PROCESS_GLOBS, _OP_GREP_FALLBACK_PHRASES, body
        )
        print("true" if result else "false")
        return 0 if result else 1

    if args.command == "adr-clause":
        reg = _load_yaml_file(Path(args.registry_file))
        now_date = date.fromisoformat(args.now) if args.now else date.today()
        result = adr_clause(args.clause_id, reg, now_date)
        print("true" if result else "false")
        return 0 if result else 1

    return 1


if __name__ == "__main__":
    sys.exit(main())
