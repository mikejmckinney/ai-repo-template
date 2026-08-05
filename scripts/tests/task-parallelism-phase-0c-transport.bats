#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism"
  PROTOCOL="${REPO_ROOT}/.context/benchmarks/model-roi/task-parallelism"
  REPORT="${BATS_TEST_TMPDIR}/phase-0c-preflight.json"
}

@test "Phase 0C structural validation does not import live transport dependencies" {
  run python3 - "${RUNNER}" "${PROTOCOL}/phase-0c-transport/manifest.json" <<'PY'
import builtins
import copy
import importlib.util
import sys
from pathlib import Path

runner, manifest = sys.argv[1:]
sys.path.insert(0, runner)
real_import = builtins.__import__

def reject_live_dependencies(name, *args, **kwargs):
    if name.split(".", 1)[0] in {"a2a", "httpx", "uvicorn"}:
        raise AssertionError(f"validate-only imported live dependency: {name}")
    return real_import(name, *args, **kwargs)

builtins.__import__ = reject_live_dependencies
spec = importlib.util.spec_from_file_location("phase_0c_preflight", f"{runner}/phase-0c-preflight.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
real_load_json = module.load_json

def load_with_bad_fixture_digest(path):
    document = real_load_json(path)
    if path.resolve() == Path(manifest).resolve():
        document = copy.deepcopy(document)
        document["canonical_event_fixture"]["sha256"] = "0" * 64
    return document

module.load_json = load_with_bad_fixture_digest
try:
    module.validate_apparatus(Path(manifest))
except ValueError as error:
    assert str(error) == "canonical event fixture digest mismatch"
else:
    raise AssertionError("changed canonical event fixture digest was accepted")
module.load_json = real_load_json
sys.argv = [spec.origin, "--validate-only", "--manifest", manifest]
raise SystemExit(module.main())
PY
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'Phase 0C apparatus validates'* ]]
}

@test "Phase 0C causal freeze rejects every non-transport treatment difference" {
  run python3 - "${RUNNER}" <<'PY'
import copy
import sys

sys.path.insert(0, sys.argv[1])
from phase_0c_freeze import CausalFreezeError, validate_treatment_pair

common = {
    "preflight_fixture_graph_sha256": "a" * 64,
    "preflight_fixture_gate_sha256": "b" * 64,
    "preflight_fixture_prompt_sha256": "c" * 64,
    "runtime": {"model": "gpt-5.6-luna", "effort": "max"},
    "topology": {"parent": 1, "children": 2, "integration": 1},
    "timeout_seconds": 2700,
    "evaluator": ["install", "browser", "unit", "build", "stage-1-playwright"],
}
c = {**common, "transport": {"backend": "github-fixture", "backend_evidence": "fixture-ledger"}}
d = {**common, "transport": {"backend": "a2a-1.0-loopback-jsonrpc", "backend_evidence": "wire-ledger"}}
validate_treatment_pair(c, d)
drifted = copy.deepcopy(d)
drifted["timeout_seconds"] = 2699
try:
    validate_treatment_pair(c, drifted)
except CausalFreezeError:
    pass
else:
    raise AssertionError("non-transport drift was accepted")
print("phase-0c causal freeze contract passed")
PY
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'phase-0c causal freeze contract passed'* ]]
}

@test "GitHub comments round trip canonical events and reject changed duplicates" {
  run python3 - "${RUNNER}" <<'PY'
import copy
import sys

sys.path.insert(0, sys.argv[1])
from phase_0c_transport import (
    CanonicalEventError,
    GitHubCommentAdapter,
    github_event_body,
    require_equal_suppressed,
)

event = {
    "event_id": "p0c-event-001",
    "sequence": 1,
    "task_id": "combat-engine",
    "kind": "task-assigned",
    "payload": {"assignee": "child-1"},
}
comments = [
    {"body": "ordinary discussion"},
    {"body": github_event_body(event).replace("\n", "\r\n")},
    {"body": github_event_body(event)},
]
adapter = GitHubCommentAdapter(comments)
ledger, suppressed = adapter.receive(expected_count=2)
assert suppressed == 1
assert adapter.marked_count == 2
assert len(ledger) == 1
assert ledger[0]["event_id"] == event["event_id"]
assert GitHubCommentAdapter([{"body": "ordinary discussion"}]).receive() == ([], 0)
assert require_equal_suppressed(1, 1) == 1
try:
    require_equal_suppressed(1, 0)
except CanonicalEventError:
    pass
else:
    raise AssertionError("different suppression counts were accepted")

missing_first = copy.deepcopy(event)
missing_first["event_id"] = "p0c-event-002"
missing_first["sequence"] = 2
try:
    GitHubCommentAdapter([{"body": github_event_body(missing_first)}]).receive(
        expected_count=2
    )
except CanonicalEventError as error:
    assert str(error) == "GitHub marked event count differs from expected count"
else:
    raise AssertionError("missing marked GitHub event was accepted")

changed = copy.deepcopy(event)
changed["payload"]["assignee"] = "child-2"
try:
    GitHubCommentAdapter(
        [{"body": github_event_body(event)}, {"body": github_event_body(changed)}]
    ).receive()
except CanonicalEventError:
    pass
else:
    raise AssertionError("changed duplicate GitHub event was accepted")
print("phase-0c GitHub comment adapter contract passed")
PY
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'phase-0c GitHub comment adapter contract passed'* ]]
}

@test "local A2A preflight rejects missing output before transport work" {
  run python3 "${RUNNER}/phase-0c-preflight.py" \
    --manifest "${PROTOCOL}/phase-0c-transport/manifest.json"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *'--output is required unless --validate-only is used'* ]]
}

@test "A2A readiness timeout includes bounded server diagnostics" {
  run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys
import types

runner = sys.argv[1]
sys.path.insert(0, runner)
spec = importlib.util.spec_from_file_location("phase_0c_preflight", f"{runner}/phase-0c-preflight.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class FakeProcess:
    def __init__(self, *args, **kwargs):
        kwargs["stderr"].write("server stalled during startup")
        kwargs["stderr"].flush()

    def poll(self):
        return None

    def terminate(self):
        pass

    def wait(self, timeout):
        return 0

module.subprocess.Popen = FakeProcess
module.available_port = lambda: 43123
ticks = iter([0, 0, 31])
module.time.monotonic = lambda: next(ticks)
module.time.sleep = lambda _seconds: None
fake_httpx = types.SimpleNamespace(
    HTTPError=RuntimeError,
    get=lambda *_args, **_kwargs: (_ for _ in ()).throw(RuntimeError("not ready")),
)
sys.modules["httpx"] = fake_httpx

try:
    module.run_a2a_server(module.Path(runner), [])
except TimeoutError as error:
    assert "server stalled during startup" in str(error)
else:
    raise AssertionError("readiness timeout was accepted")
PY
  [ "${status}" -eq 0 ]
}

@test "live GitHub preflight requires an explicit apply flag" {
  run python3 "${RUNNER}/phase-0c-github-preflight.py" \
    --manifest "${PROTOCOL}/phase-0c-transport/manifest.json" \
    --repo "example/repository" \
    --base-ref "feature/example" \
    --base-sha "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
    --output "${REPORT}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *'requires --apply'* ]]
  [ ! -e "${REPORT}" ]
}

@test "fixture canonical events survive a real A2A payload echo round trip" {
  run python3 "${RUNNER}/phase-0c-preflight.py" \
    --manifest "${PROTOCOL}/phase-0c-transport/manifest.json" \
    --output "${REPORT}"
  if [ "${status}" -ne 0 ]; then
    printf '%s\n' "${output}" >&2
  fi
  [ "${status}" -eq 0 ]
  [ -f "${REPORT}" ]

  run jq -e '
    .status == "pass" and
    .candidate_processes_started == 0 and
    .a2a.protocol_version == "1.0" and
    .a2a.specification_release == "1.0.0" and
    .a2a.sdk_version == "1.1.2" and
    .a2a.loopback_only == true and
    .a2a.separate_server_process == true and
    .a2a.discovery_path == "/.well-known/agent-card.json" and
    .a2a.discovery_succeeded == true and
    .a2a.version_header_validated == true and
    .a2a.validated_version_header == "1.0" and
    .a2a.structured_non_streaming_round_trip == true and
    .canonical_payload_echo_equivalent == true and
    .duplicate_events_suppressed == 1 and
    (.canonical_ledger | length) == 7 and
    ([.canonical_ledger[].kind] == [
      "task-assigned", "task-status", "artifact-published", "task-reclassified",
      "task-status", "task-failed", "task-status"
    ]) and
    ([.canonical_ledger[].event_id] | unique | length) == 7 and
    ([.canonical_ledger[].payload_sha256 | test("^[0-9a-f]{64}$")] | all) and
    .future_paid_topology_limit == {
      "shared_planner": 1,
      "per_arm": {"parent_implementer": 1, "writable_children": 2, "integration": 1, "maximum_processes": 4},
      "matched_pair_maximum_processes": 9,
      "maximum_simultaneous_processes": 3,
      "arms_execute_sequentially": true,
      "candidate_defect_replacements": 0
    }
  ' "${REPORT}"
  [ "${status}" -eq 0 ]
}
