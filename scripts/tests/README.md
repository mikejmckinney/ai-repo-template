# scripts/tests/

Bats test suite (issue #255 Phase 4b). Each `.bats` file in this directory is a TAP-compliant test file that wraps the matching legacy `scripts/test-<name>.sh` script.

## Layout

| `.bats` file | Legacy script wrapped | Concern |
|---|---|---|
| `auto-rebase-overlapping.bats` | `test-auto-rebase-overlapping.sh` | ADR-010 auto-rebase logic |
| `compliance-contracts.bats` | n/a (Python validators) | ADR-026 compliance schema examples and fixtures |
| `jq-filters.bats` | `test-jq-filters.sh` | `scripts/lib/jq/*.jq` fixture-driven tests |
| `multi-dispatch-safety.bats` | `test-multi-dispatch-safety.sh` | `agent-multi-dispatch.yml` ownership safety |
| `parallelism-report-parser.bats` | `test-parallelism-report-parser.sh` | Parallelism report parser |
| `phase4-fallback-parser.bats` | `test-phase4-fallback-parser.sh` | Phase-4 Copilot fallback parser |
| `pr-iteration-stats.bats` | `test-pr-iteration-stats.sh` | `pr-iteration-stats.sh` rolling metrics |
| `verify-env.bats` | `test-verify-env.sh` | `verify-env.sh` environment checks |
| `verify-pr.bats` | `test-verify-pr.sh` | `verify-pr.sh` Change-class classifier (ADR-016) |

## Running

```bash
# Run the whole suite
bats scripts/tests/

# Run one file
bats scripts/tests/verify-env.bats

# Parallel execution (requires GNU parallel — apt: parallel)
bats --jobs 4 scripts/tests/

# TAP output (default)
bats --tap scripts/tests/
```

## Installation

```bash
# Ubuntu/Debian (parallel is required for `bats --jobs`)
sudo apt-get install -y bats parallel

# macOS
brew install bats-core parallel
```

CI installs both via `apt-get install -y bats parallel` in `.github/workflows/ci-tests.yml`.

## Migration approach (Phase 4b scope)

This phase establishes the **infrastructure**: bats is installed in CI, the directory exists, and every legacy `test-<name>.sh` is reachable via a named `@test` case. Each `.bats` file currently contains **one** `@test` per concern that delegates to the legacy script.

Finer-grained per-test splitting (e.g., `test-verify-env.sh` contains multiple fixture cases that should each become their own `@test`) is **out of scope for Phase 4b**. It's tracked as follow-up because:

1. The legacy scripts are already passing in CI; converting them in-place gives us bats parallelism + TAP output now without re-implementing already-working logic.
2. The split-per-fixture work is best done concern-by-concern in dedicated PRs where reviewers can verify parity with the legacy assertions side-by-side.

The legacy `scripts/test-<name>.sh` files **stay in place** for this phase — both forms run in CI, which is the parity-check the issue plan calls for. Phase 4d removes the legacy scripts after a green soak.

## Conventions

- One `@test` per concern in this phase. Future PRs may split into multiple `@test` cases.
- `@test` names use the legacy script's filename minus the `test-` prefix and `.sh` suffix.
- Per-test timeout is set at **file-load time** via top-level `export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"` (5 min). Setting `BATS_TEST_TIMEOUT` inside `setup()` is a no-op — bats reads it in the parent process before forking the subprocess. Override per-run with `BATS_TEST_TIMEOUT=600 bats scripts/tests/`.
- No bats helper libraries (bats-assert, bats-support) are required yet — wrapping mode doesn't need them. Add when finer-grained `@test` cases land.
