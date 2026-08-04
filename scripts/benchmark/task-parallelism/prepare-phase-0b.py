#!/usr/bin/env python3

import argparse
import hashlib
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError


REPO_ROOT = Path(__file__).resolve().parents[3]
PROTOCOL_ROOT = REPO_ROOT / ".context/benchmarks/model-roi/task-parallelism"
DEFAULT_MANIFEST = PROTOCOL_ROOT / "campaign.phase-0b.preparation.json"
PREPARATION_SCHEMA = PROTOCOL_ROOT / "phase-0b-preparation.schema.json"
SUMMARY_SCHEMA = PROTOCOL_ROOT / "phase-0b-pilot-summary.schema.json"
CANDIDATE_RESULT_SCHEMA = PROTOCOL_ROOT / "phase-0b-candidate-result.schema.json"


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_schema(instance: dict, schema_path: Path) -> None:
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(instance)


def validate_schema_definition(schema_path: Path) -> None:
    Draft202012Validator.check_schema(load_json(schema_path))


def validate_execution_boundary(manifest: dict) -> None:
    execution = manifest.get("execution", {})
    if execution.get("status") != "blocked" or execution.get("approval_source") is not None:
        raise ValueError("execution approval must remain blocked during preparation")
    if execution.get("candidate_processes_started") != 0:
        raise ValueError("candidate process count must remain zero during preparation")


def validate_runtime(manifest: dict) -> None:
    runtime = manifest["candidate_runtime"]
    command = runtime["candidate_command"]
    if "danger-full-access" in command:
        raise ValueError("candidate command must not use danger-full-access")
    sandbox_index = command.index("--sandbox") if "--sandbox" in command else -1
    if sandbox_index < 0 or command[sandbox_index + 1] != "workspace-write":
        raise ValueError("candidate command must explicitly use workspace-write")

    config_path = REPO_ROOT / ".codex/config.toml"
    if sha256(config_path) != runtime["repository_config_sha256"]:
        raise ValueError("repository Codex config digest mismatch")

    evidence = load_json(PROTOCOL_ROOT / runtime["evidence"])
    contexts = evidence.get("contexts", [])
    if len(contexts) != runtime["observed_contexts"]:
        raise ValueError("runtime evidence context count mismatch")
    for context in contexts:
        if context.get("model") != runtime["model"]:
            raise ValueError("runtime evidence model mismatch")
        if context.get("reasoning_effort") != runtime["reasoning_effort"]:
            raise ValueError("runtime evidence reasoning effort mismatch")
        if context.get("status") != "completed":
            raise ValueError("runtime evidence contains an incomplete diagnostic")


def validate_files(manifest: dict, scaffold_root: Path) -> None:
    for relative_path, expected in manifest["scaffold"]["files"].items():
        path = scaffold_root / relative_path
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"scaffold digest mismatch: {relative_path}")

    for prompt in manifest["prompts"].values():
        path = PROTOCOL_ROOT / prompt["path"]
        if not path.is_file() or sha256(path) != prompt["sha256"]:
            raise ValueError(f"prompt digest mismatch: {prompt['path']}")


def validate_run_policy(manifest: dict) -> None:
    policy = manifest["run_policy"]
    expected_arms = [arm for block in policy["blocks"] for arm in block]
    assignments = policy["assignments"]
    observed_arms = [assignment["arm"] for assignment in assignments]
    if observed_arms != expected_arms:
        raise ValueError("assignment order does not match counterbalanced blocks")
    if len({assignment["run_id"] for assignment in assignments}) != 10:
        raise ValueError("Phase 0B run identifiers must be unique")
    if observed_arms.count("A") != 5 or observed_arms.count("B") != 5:
        raise ValueError("Phase 0B requires five assignments per arm")


def validate_preparation(manifest_path: Path, scaffold_root: Path) -> dict:
    manifest = load_json(manifest_path)
    validate_execution_boundary(manifest)
    validate_schema(manifest, PREPARATION_SCHEMA)
    validate_runtime(manifest)
    validate_files(manifest, scaffold_root)
    validate_run_policy(manifest)
    return manifest


def build_plan(manifest: dict) -> dict:
    prompt_paths = {
        "A": [manifest["prompts"]["common"]["path"], manifest["prompts"]["arm_a"]["path"]],
        "B": [manifest["prompts"]["common"]["path"], manifest["prompts"]["arm_b"]["path"]],
    }
    assignments = [
        {**assignment, "prompt_paths": prompt_paths[assignment["arm"]]}
        for assignment in manifest["run_policy"]["assignments"]
    ]
    return {
        "schema_version": "task-parallelism-phase-0b-run-plan.v1",
        "campaign_id": manifest["campaign_id"],
        "execution_status": manifest["execution"]["status"],
        "candidate_processes_started": 0,
        "candidate_command": manifest["candidate_runtime"]["candidate_command"],
        "scaffold_base_status": manifest["scaffold"]["base_status"],
        "assignments": assignments,
        "retries": manifest["run_policy"]["retries"],
        "gate_0": manifest["gate_0"],
    }


def write_plan(manifest: dict, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(build_plan(manifest), indent=2) + "\n", encoding="utf-8")
    print(f"wrote blocked Phase 0B run plan: {output_path}")


def evaluate_gate(summary_path: Path, manifest: dict) -> int:
    summary = load_json(summary_path)
    validate_schema(summary, SUMMARY_SCHEMA)
    thresholds = manifest["gate_0"]
    failures = []
    if summary["terminal_runs"] < thresholds["terminal_runs"]:
        failures.append(
            f"terminal runs {summary['terminal_runs']} is below {thresholds['terminal_runs']}"
        )
    if summary["required_telemetry_fraction"] < thresholds["required_telemetry_fraction"]:
        failures.append(
            "required telemetry fraction "
            f"{summary['required_telemetry_fraction']:g} is below "
            f"{thresholds['required_telemetry_fraction']:g}"
        )
    if summary["harness_reliability_fraction"] < thresholds["harness_reliability_fraction"]:
        failures.append(
            "harness reliability "
            f"{summary['harness_reliability_fraction']:g} is below "
            f"{thresholds['harness_reliability_fraction']:g}"
        )
    if summary["arm_b_fanout_elections"] < thresholds["arm_b_fanout_elections"]:
        failures.append(
            "Arm B fan-out elections "
            f"{summary['arm_b_fanout_elections']} is below "
            f"{thresholds['arm_b_fanout_elections']}"
        )

    if failures:
        print("Gate 0: no-go")
        for failure in failures:
            print(f"- {failure}")
        return 3
    print("Gate 0: go")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare the blocked Phase 0B pilot plan")
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--validate", action="store_true")
    action.add_argument("--plan", type=Path)
    action.add_argument("--evaluate-gate", type=Path)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--scaffold-root", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest_path = args.manifest.resolve()
        manifest = load_json(manifest_path)
        default_scaffold = PROTOCOL_ROOT / manifest.get("scaffold", {}).get("path", "scaffold")
        scaffold_root = (args.scaffold_root or default_scaffold).resolve()
        manifest = validate_preparation(manifest_path, scaffold_root)
        if args.validate or args.plan:
            validate_schema_definition(CANDIDATE_RESULT_SCHEMA)
        if args.validate:
            print("Phase 0B preparation is valid and execution remains blocked")
            return 0
        if args.plan:
            write_plan(manifest, args.plan.resolve())
            return 0
        return evaluate_gate(args.evaluate_gate.resolve(), manifest)
    except (OSError, ValueError, json.JSONDecodeError, SchemaError, ValidationError) as error:
        print(f"Phase 0B preparation invalid: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
