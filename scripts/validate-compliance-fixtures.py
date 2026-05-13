#!/usr/bin/env python3
"""Validate ADR-026 compliance fixtures.

Default mode expects every file under fixtures/compliance/valid to pass and
every file under fixtures/compliance/invalid to fail. Use --single for a direct
one-file validation result.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from compliance_schema import ComplianceError, load_yaml, validate_loaded_block  # noqa: E402


def resolve_input_path(path: Path) -> Path:
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def source_name(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def validate_file(path: Path) -> None:
    resolved = resolve_input_path(path)
    if not resolved.is_file():
        raise ComplianceError(f"{source_name(resolved)}: file does not exist")
    validate_loaded_block(load_yaml(resolved), source_name(resolved), REPO_ROOT)


def iter_yaml_files(path: Path) -> list[Path]:
    return sorted([*path.glob("*.yml"), *path.glob("*.yaml")])


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_fixtures_dir = REPO_ROOT / "scripts" / "tests" / "fixtures" / "compliance"
    fixture_dir_args = parser.add_mutually_exclusive_group()
    fixture_dir_args.add_argument(
        "fixtures_dir",
        nargs="?",
        type=Path,
        help="fixture directory to validate; alias for --fixtures-dir",
    )
    fixture_dir_args.add_argument(
        "--fixtures-dir",
        dest="fixtures_dir_option",
        type=Path,
        default=None,
        help="fixture directory to validate",
    )
    parser.add_argument("--single", type=Path, help="validate one YAML file; exit non-zero on validation failure")
    args = parser.parse_args(argv[1:])

    fixtures_dir = resolve_input_path(args.fixtures_dir_option or args.fixtures_dir or default_fixtures_dir)

    if args.single:
        validate_file(args.single)
        print(f"valid compliance fixture: {args.single}")
        return 0

    valid_dir = fixtures_dir / "valid"
    invalid_dir = fixtures_dir / "invalid"
    if not valid_dir.is_dir() or not invalid_dir.is_dir():
        print(f"missing fixture directories under {source_name(fixtures_dir)}", file=sys.stderr)
        return 1

    valid_files = iter_yaml_files(valid_dir)
    invalid_files = iter_yaml_files(invalid_dir)
    if not valid_files or not invalid_files:
        print("expected at least one valid and one invalid compliance fixture", file=sys.stderr)
        return 1

    failures: list[str] = []

    for path in valid_files:
        try:
            validate_file(path)
        except ComplianceError as exc:
            failures.append(f"expected valid but failed: {source_name(path)} — {exc}")

    for path in invalid_files:
        try:
            validate_file(path)
        except ComplianceError:
            continue
        failures.append(f"expected invalid but passed: {source_name(path)}")

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1

    print(f"validated {len(valid_files)} valid and {len(invalid_files)} invalid compliance fixture(s)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except ComplianceError as exc:
        print(f"compliance fixture validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
