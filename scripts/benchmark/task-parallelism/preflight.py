#!/usr/bin/env python3
import argparse
import hashlib
import importlib.metadata
import json
import os
import re
import sys
from pathlib import Path

from jsonschema import Draft202012Validator


EXPECTED_JSONSCHEMA = "4.26.0"
SCHEMA_DRAFT = "https://json-schema.org/draft/2020-12/schema"
EXPECTED_ASSET_PATHS = {
    "audio/enemy-defeat.wav",
    "audio/enemy-hit.wav",
    "audio/game-over.wav",
    "audio/gameplay-loop.mp3",
    "audio/menu-theme.mp3",
    "audio/player-hit.wav",
    "audio/shoot.wav",
    "audio/wave-start.wav",
    "source/primitives.json",
    "visuals/arena-background.webp",
    "visuals/effects/explosion-atlas.json",
    "visuals/effects/explosion-atlas.webp",
    "visuals/effects/impact-atlas.json",
    "visuals/effects/impact-atlas.webp",
    "visuals/enemies/chaser.webp",
    "visuals/enemies/striker.webp",
    "visuals/enemies/tank.webp",
    "visuals/logo.webp",
    "visuals/manifest.json",
    "visuals/menu-background.webp",
    "visuals/palette.json",
    "visuals/pickups/health.webp",
    "visuals/pickups/rapid-fire.webp",
    "visuals/player.webp",
    "visuals/ui/heart.webp",
    "visuals/ui/score.webp",
    "visuals/ui/wave.webp",
}
PROVIDER_CREDENTIAL_PATTERN = re.compile(
    r"(?:API_KEY|API_TOKEN|AUTH_TOKEN|ACCESS_TOKEN|SECRET|PASSWORD|CREDENTIAL)$"
)
SECRET_VALUE_PATTERN = re.compile(
    r"(?:(?:^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{8,}|fixture-secret-value|-----BEGIN [A-Z ]+ PRIVATE KEY-----)"
)


def load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def validate(instance: object, schema_path: Path, label: str) -> None:
    schema = load_json(schema_path)
    if schema.get("$schema") != SCHEMA_DRAFT:
        raise ValueError(f"{label} schema must declare Draft 2020-12")
    Draft202012Validator.check_schema(schema)
    errors = sorted(Draft202012Validator(schema).iter_errors(instance), key=lambda e: list(e.path))
    if errors:
        raise ValueError(f"{label} is invalid: {errors[0].message}")


def find_secret(value: object) -> bool:
    if isinstance(value, dict):
        return any(find_secret(item) for item in value.values())
    if isinstance(value, list):
        return any(find_secret(item) for item in value)
    return isinstance(value, str) and bool(SECRET_VALUE_PATTERN.search(value))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def network_namespace_active() -> bool:
    try:
        parent_namespace = os.environ["PARENT_NET_NAMESPACE"]
        return os.readlink("/proc/self/ns/net") != parent_namespace
    except OSError:
        return False
    except KeyError:
        return False


def validate_assets(protocol_dir: Path, manifest_path: Path) -> dict[str, object]:
    manifest = load_json(manifest_path)
    validate(manifest, protocol_dir / "asset-manifest.schema.json", "asset manifest")
    assets_dir = protocol_dir / "assets"
    paths = {asset["path"] for asset in manifest["assets"]}
    if paths != EXPECTED_ASSET_PATHS:
        raise ValueError("asset manifest is invalid: required path set mismatch")
    for asset in manifest["assets"]:
        path = assets_dir / asset["path"]
        if not path.is_file():
            raise ValueError(f"asset is missing: {asset['path']}")
        if path.stat().st_size != asset["bytes"] or sha256(path) != asset["sha256"]:
            raise ValueError(f"asset checksum mismatch: {asset['path']}")
    return {"status": "pass", "count": len(manifest["assets"]), "manifest_sha256": sha256(manifest_path)}


def fixture_manifest_path(fixture: Path, protocol_dir: Path, campaign: dict[str, object]) -> Path:
    if fixture.name == "invalid-asset-manifest.json":
        return fixture
    configured = Path(str(campaign["assets"]["manifest"]))
    return protocol_dir / configured


def evaluate(
    campaign_path: Path,
    fixture: Path | None = None,
    audit_hook_active: bool = False,
) -> dict[str, object]:
    repo_root = Path(os.environ.get("REPO_ROOT", Path(__file__).resolve().parents[3]))
    protocol_dir = repo_root / ".context/benchmarks/model-roi/task-parallelism"
    campaign = load_json(campaign_path)
    validate(campaign, protocol_dir / "campaign.schema.json", "campaign")

    if find_secret(campaign):
        raise ValueError("secret-shaped value is forbidden")
    if campaign["freeze_state"]["status"] != "resolved":
        raise ValueError("freeze state is unresolved")
    if campaign["phase_0b"]["status"] != "blocked":
        raise ValueError("Phase 0B approval must remain blocked")
    if campaign["external_operations"]:
        raise ValueError("external operation is forbidden")

    manifest_path = fixture_manifest_path(fixture, protocol_dir, campaign) if fixture else protocol_dir / campaign["assets"]["manifest"]
    assets = validate_assets(protocol_dir, manifest_path)
    provider_credentials = sorted(name for name in os.environ if PROVIDER_CREDENTIAL_PATTERN.search(name))
    return {
        "status": "pass",
        "campaign": campaign["campaign_id"],
        "campaign_source": str(campaign_path.resolve().relative_to(repo_root)),
        "campaign_sha256": sha256(campaign_path),
        "freeze_state": campaign["freeze_state"]["status"],
        "assets": assets,
        "isolation": {
            "network_namespace": "active" if network_namespace_active() else "inactive",
            "provider_credentials_present": provider_credentials,
            "python_audit_hook": "active" if audit_hook_active else "inactive",
        },
        "phase_0b": campaign["phase_0b"]["status"],
    }


def run_preflight(audit_hook_active: bool = False) -> int:
    repo_root = Path(os.environ["REPO_ROOT"])
    protocol_dir = repo_root / ".context/benchmarks/model-roi/task-parallelism"
    campaign_path = protocol_dir / "campaign.phase-0a.json"
    try:
        report = evaluate(campaign_path, audit_hook_active=audit_hook_active)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"task-parallelism preflight failed: {exc}", file=sys.stderr)
        return 1

    report_path = Path(os.environ["REPORT_PATH"])
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("task-parallelism preflight passed; Phase 0B remains blocked")
    return 0


def run_fixture_suite(fixture_values: list[str]) -> int:
    repo_root = Path(os.environ["REPO_ROOT"])
    protocol_dir = repo_root / ".context/benchmarks/model-roi/task-parallelism"
    unexpected_passes = 0
    for fixture_value in fixture_values:
        fixture = Path(fixture_value).resolve()
        campaign_path = fixture if fixture.name != "invalid-asset-manifest.json" else protocol_dir / "campaign.phase-0a.json"
        try:
            evaluate(campaign_path, fixture)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            print(f"{fixture.name}: {exc}", file=sys.stderr)
        else:
            print(f"{fixture.name}: unexpectedly passed", file=sys.stderr)
            unexpected_passes += 1
    return 2 if unexpected_passes else 1


def validate_only() -> int:
    version = importlib.metadata.version("jsonschema")
    if version != EXPECTED_JSONSCHEMA:
        raise SystemExit(f"jsonschema {EXPECTED_JSONSCHEMA} required, found {version}")
    validate_structure()
    print(f"Draft 2020-12 campaign and asset schemas valid with jsonschema {version}")
    return 0


def validate_structure() -> int:
    repo_root = Path(__file__).resolve().parents[3]
    campaign = repo_root / ".context/benchmarks/model-roi/task-parallelism/campaign.phase-0a.json"
    evaluate(campaign)
    print("Draft 2020-12 campaign and asset schemas structurally valid")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--validate-structure", action="store_true")
    args = parser.parse_args()
    if args.validate_only == args.validate_structure:
        parser.error("choose exactly one validation mode outside the isolated launcher")
    return validate_only() if args.validate_only else validate_structure()


if __name__ == "__main__":
    raise SystemExit(main())
