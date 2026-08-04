# Task-Parallelism Benchmark: Phase 0A

Phase 0A is the deterministic, no-spend readiness boundary for issue #545. It
validates the tracked Vector Siege campaign record and exact placeholder assets;
it does not execute candidates or authorize Phase 0B.

## Contract

- `campaign.phase-0a.json` is the only production campaign input. Files under
  `scripts/benchmark/task-parallelism/fixtures/` are test-only and cannot replace
  it through the argument-free Make target.
- Both schemas declare JSON Schema Draft 2020-12 and validation requires exactly
  `jsonschema==4.26.0`. Preflight never installs dependencies.
- Placeholder MP3, WAV, WebP, palette, atlas, and manifest files are generated
  locally from `assets/source/primitives.json` with FFmpeg `6.1.1-3ubuntu5`.
- `make -C scripts/benchmark/task-parallelism preflight` clears the environment,
  enters a user and network namespace with `unshare -Urn`, installs a Python
  audit hook for the named socket and child-process paths, and validates only
  local tracked files.

This is bounded validator isolation, not a hostile-code sandbox. Unsupported
hosts and version mismatches fail closed.

## Commands

```bash
make -C scripts/benchmark/task-parallelism assets-check
make -C scripts/benchmark/task-parallelism preflight
jq '{status, campaign, freeze_state, assets, isolation, phase_0b}' \
  .artifacts/task-parallelism/preflight-report.json
bats --tap scripts/tests/task-parallelism-preflight.bats
```

The report contains names, booleans, counts, and checksums only. Provider
credential values are neither inherited nor emitted.

## Approval Boundary

Passing Phase 0A means the local apparatus is reproducible and fail-closed. It
does not approve candidate invocations, paid generation, network access,
Cloudflare changes, deployment, publication, A2A, portability tests, or an
ADR-031 policy change. Phase 0B requires a separate explicit maintainer approval.
