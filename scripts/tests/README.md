# scripts/tests/

Bats is the focused behavior and fixture test suite. Tests run directly from
this directory; removed `scripts/test-*.sh` wrappers are not a second execution
path.

## Layout

| Example | Concern |
|---|---|---|
| `generated-governance-surfaces.bats` | Canonical-source generation and stale-output detection |
| `codespace-cache-cleanup.bats` | Dry-run and bounded Codespaces cache cleanup behavior |
| `codespace-tools.bats` | Codespaces tool manifest and idempotent installer behavior |
| `orchestration.bats` | Multi-model consensus provider and Fusion behavior |
| `opencode-oauth-actions.bats` | Access-only OAuth sync, expiry routing, and fix isolation |
| `postmerge-retro-batch.bats` | Daily retro evidence and lifecycle behavior |
| `shell-tooling-policy.bats` | Bounded production shell command policy |
| `verify-env.bats` | Environment checks |
| `verify-pr.bats` | Change-class classifier fixtures (ADR-016) |
| `weekly-classifier.bats` | Weekly review classifier behavior |

Files may contain multiple focused `@test` cases or one inlined historical
harness while it is split incrementally. They must not invoke a removed external
test wrapper.

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
sudo apt-get install -y bats parallel ripgrep

# macOS
brew install bats-core parallel
```

CI installs them via `apt-get install -y bats parallel ripgrep` in `.github/workflows/ci-tests.yml`.
Run this suite separately from `./test.sh`; neither command invokes the other.

## Conventions

- Name tests for observable behavior rather than an implementation phase.
- Keep fixtures local, deterministic, and independent of network access.
- Add the failing fixture before changing the behavior it protects.
- Per-test timeout is set at **file-load time** via top-level `export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"` (5 min). Setting `BATS_TEST_TIMEOUT` inside `setup()` is a no-op — bats reads it in the parent process before forking the subprocess. Override per-run with `BATS_TEST_TIMEOUT=600 bats scripts/tests/`.
- No bats helper libraries are required. Add one only when repeated assertion
  code justifies the dependency.
