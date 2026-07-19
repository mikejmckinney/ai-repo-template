#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from pathlib import Path, PurePosixPath


HASH_ALGORITHM = "sha256-tree-v1"
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")
HASH_PATTERN = re.compile(r"^[0-9a-f]{64}$")
SOURCE_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
SKILL_NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class SupplyChainError(Exception):
    pass


def safe_relative_path(value: object, field: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value:
        raise SupplyChainError(f"{field} must be a non-empty POSIX relative path")
    if "" in value.split("/") or "." in value.split("/") or ".." in value.split("/"):
        raise SupplyChainError(f"{field} contains path traversal: {value}")

    path = PurePosixPath(value)
    if path.is_absolute():
        raise SupplyChainError(f"{field} must be relative: {value}")
    return path


def package_files(package: Path) -> list[Path]:
    if package.is_symlink():
        raise SupplyChainError(f"package path is a symlink: {package}")
    if not package.is_dir():
        raise SupplyChainError(f"package directory does not exist: {package}")

    files: list[Path] = []
    for root, directories, filenames in os.walk(package, followlinks=False):
        root_path = Path(root)
        directories[:] = sorted(directory for directory in directories if directory != ".git")

        for directory in directories:
            path = root_path / directory
            if path.is_symlink():
                raise SupplyChainError(f"package contains symlink directory: {path}")

        for filename in sorted(filenames):
            path = root_path / filename
            if path.is_symlink():
                raise SupplyChainError(f"package contains symlink file: {path}")
            if not path.is_file():
                raise SupplyChainError(f"package contains non-regular file: {path}")
            files.append(path)

    return sorted(files, key=lambda path: path.relative_to(package).as_posix())


def package_hash(package: Path) -> str:
    digest = hashlib.sha256()
    digest.update(f"{HASH_ALGORITHM}\0".encode())

    for path in package_files(package):
        relative_path = path.relative_to(package).as_posix().encode()
        data = path.read_bytes()
        executable = bool(path.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH))
        mode = b"100755" if executable else b"100644"
        digest.update(relative_path)
        digest.update(b"\0")
        digest.update(mode)
        digest.update(b"\0")
        digest.update(str(len(data)).encode())
        digest.update(b"\0")
        digest.update(data)
        digest.update(b"\0")

    return digest.hexdigest()


def load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise SupplyChainError(f"cannot read JSON from {path}: {error}") from error
    if not isinstance(value, dict):
        raise SupplyChainError(f"JSON root must be an object: {path}")
    return value


def skill_name(skill_file: Path) -> str:
    try:
        lines = skill_file.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as error:
        raise SupplyChainError(f"cannot read skill metadata from {skill_file}: {error}") from error

    if not lines or lines[0] != "---":
        raise SupplyChainError(f"malformed skill metadata in {skill_file}: missing frontmatter")

    for line in lines[1:]:
        if line == "---":
            break
        if line.startswith("name:"):
            name = line.removeprefix("name:").strip().strip('"\'')
            if not SKILL_NAME_PATTERN.fullmatch(name):
                raise SupplyChainError(f"malformed skill name in {skill_file}: {name}")
            return name
    raise SupplyChainError(f"malformed skill metadata in {skill_file}: missing name")


def confined_destination(repo: Path, value: object, field: str) -> Path:
    relative = safe_relative_path(value, field)
    if relative.parts[:2] != (".agents", "skills") or len(relative.parts) < 3:
        raise SupplyChainError(f"{field} must be under .agents/skills: {relative}")

    destination = repo.joinpath(*relative.parts)
    if destination.is_symlink():
        raise SupplyChainError(f"{field} is a symlink: {relative}")
    if not destination.is_dir():
        raise SupplyChainError(f"{field} does not exist: {relative}")

    try:
        destination.resolve().relative_to(repo.resolve())
    except ValueError as error:
        raise SupplyChainError(f"{field} escapes repository: {relative}") from error
    return destination


def validate_external_record(repo: Path, key: str, record: object) -> tuple[Path, str]:
    if not isinstance(record, dict):
        raise SupplyChainError(f"external skill record must be an object: {key}")

    required_fields = {
        "source",
        "ref",
        "sourceType",
        "skillPath",
        "destinationPath",
        "hashAlgorithm",
        "computedHash",
    }
    missing = sorted(required_fields - record.keys())
    if missing:
        raise SupplyChainError(f"external skill {key} is missing fields: {', '.join(missing)}")
    if not isinstance(record["source"], str) or not SOURCE_PATTERN.fullmatch(record["source"]):
        raise SupplyChainError(f"external skill {key} has invalid source")
    if record["sourceType"] != "github":
        raise SupplyChainError(f"external skill {key} has unsupported sourceType")
    if not isinstance(record["ref"], str) or not SHA_PATTERN.fullmatch(record["ref"]):
        raise SupplyChainError(f"external skill {key} ref must be an immutable commit SHA")
    safe_relative_path(record["skillPath"], f"external skill {key} skillPath")
    if record["hashAlgorithm"] != HASH_ALGORITHM:
        raise SupplyChainError(f"external skill {key} has unsupported hashAlgorithm")
    if not isinstance(record["computedHash"], str) or not HASH_PATTERN.fullmatch(record["computedHash"]):
        raise SupplyChainError(f"external skill {key} has invalid computedHash")

    destination = confined_destination(repo, record["destinationPath"], f"external skill {key} destinationPath")
    metadata_name = skill_name(destination / "SKILL.md")

    actual_hash = package_hash(destination)
    if actual_hash != record["computedHash"]:
        raise SupplyChainError(
            f"external skill {key} hash mismatch: expected {record['computedHash']}, got {actual_hash}"
        )
    return destination / "SKILL.md", metadata_name


def validate_owned_record(repo: Path, key: str, record: object) -> tuple[Path, str]:
    if not isinstance(record, dict) or set(record) != {"destinationPath"}:
        raise SupplyChainError(f"repository-owned skill {key} must declare only destinationPath")

    destination = confined_destination(repo, record["destinationPath"], f"owned skill {key} destinationPath")
    metadata_name = skill_name(destination / "SKILL.md")
    return destination / "SKILL.md", metadata_name


def validate_lock(repo: Path, lock_path: Path) -> None:
    lock = load_json(lock_path)
    if lock.get("version") != 2:
        raise SupplyChainError("skills lock version must be 2")

    external = lock.get("skills")
    owned = lock.get("ownedSkills")
    if not isinstance(external, dict) or not isinstance(owned, dict):
        raise SupplyChainError("skills and ownedSkills must be objects")
    overlap = sorted(external.keys() & owned.keys())
    if overlap:
        raise SupplyChainError(f"skills cannot be both external and owned: {', '.join(overlap)}")

    declared_files: set[Path] = set()
    metadata_names: dict[str, str] = {}
    for key, record in sorted(external.items()):
        skill_file, name = validate_external_record(repo, key, record)
        declared_files.add(skill_file.resolve())
        if name in metadata_names:
            raise SupplyChainError(f"duplicate skill name {name}: {metadata_names[name]} and {key}")
        metadata_names[name] = key
        if name != key:
            raise SupplyChainError(f"external skill key {key} does not match metadata name {name}")

    for key, record in sorted(owned.items()):
        skill_file, name = validate_owned_record(repo, key, record)
        declared_files.add(skill_file.resolve())
        if name in metadata_names:
            raise SupplyChainError(f"duplicate skill name {name}: {metadata_names[name]} and {key}")
        metadata_names[name] = key
        if name != key:
            raise SupplyChainError(f"repository-owned skill key {key} does not match metadata name {name}")

    skills_root = repo / ".agents" / "skills"
    discovered_files = {path.resolve() for path in skills_root.glob("**/SKILL.md")}
    undeclared = sorted(path.relative_to(repo.resolve()).as_posix() for path in discovered_files - declared_files)
    missing = sorted(path.relative_to(repo.resolve()).as_posix() for path in declared_files - discovered_files)
    if undeclared:
        raise SupplyChainError(f"undeclared skill packages: {', '.join(undeclared)}")
    if missing:
        raise SupplyChainError(f"declared skill packages are missing: {', '.join(missing)}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate and refresh vendored agent skills")
    commands = parser.add_subparsers(dest="command", required=True)

    hash_parser = commands.add_parser("hash", help="hash a skill package")
    hash_parser.add_argument("--package", required=True, type=Path)

    validate_parser = commands.add_parser("validate-lock", help="validate the skills lock")
    validate_parser.add_argument("--repo", required=True, type=Path)
    validate_parser.add_argument("--lock", required=True, type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "hash":
            print(package_hash(args.package))
        elif args.command == "validate-lock":
            validate_lock(args.repo, args.lock)
            print(json.dumps({"status": "success", "lock": str(args.lock)}))
    except SupplyChainError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
