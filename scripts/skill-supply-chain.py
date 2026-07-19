#!/usr/bin/env python3

import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path, PurePosixPath


HASH_ALGORITHM = "sha256-tree-v1"
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")
HASH_PATTERN = re.compile(r"^[0-9a-f]{64}$")
SOURCE_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
SKILL_NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MAX_ARCHIVE_FILES = 50_000
MAX_ARCHIVE_BYTES = 250 * 1024 * 1024


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


def source_packages(
    repo: Path,
    lock_path: Path,
    source: str,
    source_dir: Path,
    target_ref: str,
) -> tuple[dict, list[dict]]:
    validate_lock(repo, lock_path)
    if not SOURCE_PATTERN.fullmatch(source):
        raise SupplyChainError(f"invalid source: {source}")
    if not SHA_PATTERN.fullmatch(target_ref):
        raise SupplyChainError("target ref must be an immutable commit SHA")
    if source_dir.is_symlink() or not source_dir.is_dir():
        raise SupplyChainError(f"source directory must be a real directory: {source_dir}")

    lock = load_json(lock_path)
    selected = [
        (key, record)
        for key, record in sorted(lock["skills"].items())
        if record["source"] == source
    ]
    if not selected:
        raise SupplyChainError(f"source is not declared in the lock: {source}")

    old_refs = {record["ref"] for _, record in selected}
    if len(old_refs) != 1:
        raise SupplyChainError(f"source has inconsistent locked refs: {source}")

    packages = []
    for key, record in selected:
        upstream_relative = safe_relative_path(
            record["skillPath"], f"external skill {key} skillPath"
        )
        upstream_package = source_dir.joinpath(*upstream_relative.parts)
        metadata_name = skill_name(upstream_package / "SKILL.md")
        if metadata_name != key:
            raise SupplyChainError(
                f"external skill key {key} does not match upstream metadata name {metadata_name}"
            )

        new_hash = package_hash(upstream_package)
        old_hash = record["computedHash"]
        if target_ref == record["ref"] and new_hash != old_hash:
            raise SupplyChainError(
                f"same ref hash mismatch for {key}: {target_ref} resolves to unexpected content"
            )
        packages.append(
            {
                "key": key,
                "sourcePackage": upstream_package,
                "destination": confined_destination(
                    repo,
                    record["destinationPath"],
                    f"external skill {key} destinationPath",
                ),
                "oldHash": old_hash,
                "newHash": new_hash,
                "changed": target_ref != record["ref"] or new_hash != old_hash,
            }
        )
    return lock, packages


def change_result(source: str, old_ref: str, new_ref: str, packages: list[dict]) -> dict:
    changed_packages = [package for package in packages if package["changed"]]
    return {
        "status": "success",
        "source": source,
        "changed": bool(changed_packages),
        "oldRef": old_ref,
        "newRef": new_ref,
        "packages": [package["key"] for package in changed_packages],
        "hashes": {
            package["key"]: {
                "old": package["oldHash"],
                "new": package["newHash"],
            }
            for package in changed_packages
        },
    }


def write_json_atomically(path: Path, value: dict) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def run_git(arguments: list[str]) -> str:
    environment = os.environ.copy()
    environment.update(
        {
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
        }
    )
    command = [
        "git",
        "-c",
        "core.hooksPath=/dev/null",
        "-c",
        "credential.helper=",
        "-c",
        "protocol.file.allow=never",
        *arguments,
    ]
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        raise SupplyChainError(f"git acquisition failed: {detail}") from error
    return result.stdout.strip()


def extract_archive(archive_path: Path, destination: Path) -> None:
    file_count = 0
    total_bytes = 0
    destination.mkdir(parents=True, exist_ok=True)

    try:
        archive = tarfile.open(archive_path, mode="r:")
    except (OSError, tarfile.TarError) as error:
        raise SupplyChainError(f"cannot read source archive: {error}") from error

    with archive:
        for member in archive:
            relative = safe_relative_path(member.name.rstrip("/"), "archive member")
            target = destination.joinpath(*relative.parts)
            try:
                target.resolve().relative_to(destination.resolve())
            except ValueError as error:
                raise SupplyChainError(f"archive member escapes destination: {member.name}") from error

            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            if not member.isfile():
                raise SupplyChainError(f"archive contains unsupported link or file: {member.name}")

            file_count += 1
            total_bytes += member.size
            if file_count > MAX_ARCHIVE_FILES or total_bytes > MAX_ARCHIVE_BYTES:
                raise SupplyChainError("source archive exceeds safety limits")

            source_stream = archive.extractfile(member)
            if source_stream is None:
                raise SupplyChainError(f"cannot read archive member: {member.name}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with source_stream, target.open("wb") as destination_stream:
                shutil.copyfileobj(source_stream, destination_stream)
            target.chmod(0o755 if member.mode & 0o111 else 0o644)


def acquire_github_source(lock: dict, source: str, requested_ref: str | None, destination: Path) -> str:
    records = [record for record in lock["skills"].values() if record["source"] == source]
    if not records:
        raise SupplyChainError(f"source is not declared in the lock: {source}")
    package_paths = sorted(
        {
            safe_relative_path(record["skillPath"], "skillPath").as_posix()
            for record in records
        }
    )
    repository_url = f"https://github.com/{source}.git"

    if requested_ref is None:
        remote_head = run_git(["ls-remote", repository_url, "HEAD"])
        fields = remote_head.split()
        if len(fields) != 2 or not SHA_PATTERN.fullmatch(fields[0]):
            raise SupplyChainError(f"cannot resolve default branch head for {source}")
        requested_ref = fields[0]
    elif not SHA_PATTERN.fullmatch(requested_ref):
        raise SupplyChainError("target ref must be an immutable commit SHA")

    bare_repository = destination.parent / "source.git"
    archive_path = destination.parent / "source.tar"
    run_git(["init", "--bare", str(bare_repository)])
    run_git(
        [
            f"--git-dir={bare_repository}",
            "fetch",
            "--depth=1",
            "--filter=blob:none",
            "--no-tags",
            repository_url,
            requested_ref,
        ]
    )
    resolved_ref = run_git([f"--git-dir={bare_repository}", "rev-parse", "FETCH_HEAD"])
    if resolved_ref != requested_ref:
        raise SupplyChainError(
            f"ref mismatch for {source}: requested {requested_ref}, fetched {resolved_ref}"
        )
    run_git(
        [
            f"--git-dir={bare_repository}",
            "archive",
            "--format=tar",
            f"--output={archive_path}",
            "FETCH_HEAD",
            "--",
            *package_paths,
        ]
    )
    extract_archive(archive_path, destination)
    return resolved_ref


def run_source_operation(args: argparse.Namespace) -> dict:
    lock = load_json(args.lock)
    if args.source_dir is not None:
        if args.ref is None:
            raise SupplyChainError("--ref is required with --source-dir")
        source_dir = args.source_dir
        target_ref = args.ref
        if args.command == "check":
            _, packages = source_packages(
                args.repo, args.lock, args.source, source_dir, target_ref
            )
            old_ref = next(
                record["ref"]
                for record in lock["skills"].values()
                if record["source"] == args.source
            )
            return change_result(args.source, old_ref, target_ref, packages)
        return update_source(args.repo, args.lock, args.source, source_dir, target_ref)

    with tempfile.TemporaryDirectory(prefix="skill-source-") as temporary:
        source_dir = Path(temporary) / "source"
        target_ref = acquire_github_source(lock, args.source, args.ref, source_dir)
        if args.command == "check":
            _, packages = source_packages(
                args.repo, args.lock, args.source, source_dir, target_ref
            )
            old_ref = next(
                record["ref"]
                for record in lock["skills"].values()
                if record["source"] == args.source
            )
            return change_result(args.source, old_ref, target_ref, packages)
        return update_source(args.repo, args.lock, args.source, source_dir, target_ref)


def update_source(
    repo: Path,
    lock_path: Path,
    source: str,
    source_dir: Path,
    target_ref: str,
) -> dict:
    lock, packages = source_packages(repo, lock_path, source, source_dir, target_ref)
    old_ref = next(record["ref"] for record in lock["skills"].values() if record["source"] == source)
    result = change_result(source, old_ref, target_ref, packages)
    if not result["changed"]:
        return result

    next_lock = copy.deepcopy(lock)
    for package in packages:
        if package["changed"]:
            record = next_lock["skills"][package["key"]]
            record["ref"] = target_ref
            record["computedHash"] = package["newHash"]

    lock_backup = lock_path.read_bytes()
    with tempfile.TemporaryDirectory(prefix=".skill-refresh-", dir=repo.parent) as temporary:
        temporary_root = Path(temporary)
        staged_root = temporary_root / "staged"
        backup_root = temporary_root / "backup"
        staged_root.mkdir()
        backup_root.mkdir()

        changed_packages = [package for package in packages if package["changed"]]
        for package in changed_packages:
            shutil.copytree(
                package["sourcePackage"],
                staged_root / package["key"],
                copy_function=shutil.copy2,
            )
            if package_hash(staged_root / package["key"]) != package["newHash"]:
                raise SupplyChainError(f"staged package hash mismatch: {package['key']}")

        replaced: list[dict] = []
        try:
            for package in changed_packages:
                destination = package["destination"]
                backup = backup_root / package["key"]
                os.replace(destination, backup)
                replaced.append(package)
                os.replace(staged_root / package["key"], destination)
            write_json_atomically(lock_path, next_lock)
            validate_lock(repo, lock_path)
        except Exception:
            lock_path.write_bytes(lock_backup)
            for package in reversed(replaced):
                destination = package["destination"]
                if destination.exists():
                    shutil.rmtree(destination)
                os.replace(backup_root / package["key"], destination)
            raise
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate and refresh vendored agent skills")
    commands = parser.add_subparsers(dest="command", required=True)

    hash_parser = commands.add_parser("hash", help="hash a skill package")
    hash_parser.add_argument("--package", required=True, type=Path)

    validate_parser = commands.add_parser("validate-lock", help="validate the skills lock")
    validate_parser.add_argument("--repo", required=True, type=Path)
    validate_parser.add_argument("--lock", required=True, type=Path)

    for command in ("check", "update"):
        source_parser = commands.add_parser(command, help=f"{command} one upstream source")
        source_parser.add_argument("--repo", required=True, type=Path)
        source_parser.add_argument("--lock", required=True, type=Path)
        source_parser.add_argument("--source", required=True)
        source_parser.add_argument("--source-dir", type=Path)
        source_parser.add_argument("--ref")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "hash":
            print(package_hash(args.package))
        elif args.command == "validate-lock":
            validate_lock(args.repo, args.lock)
            print(json.dumps({"status": "success", "lock": str(args.lock)}))
        elif args.command == "check":
            print(json.dumps(run_source_operation(args), sort_keys=True))
        elif args.command == "update":
            print(json.dumps(run_source_operation(args), sort_keys=True))
    except SupplyChainError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
