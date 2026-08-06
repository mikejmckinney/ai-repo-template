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
| `onboarding-advisory-policy.bats` | Onboarding lifecycle, LSP, and advisory policy invariants |
| `postmerge-retro-batch.bats` | Daily retro evidence and lifecycle behavior |
| `sandbox-candidate.bats` | Exact-SHA sandbox stage, lease, restore, and cleanup behavior |
| `shell-tooling-policy.bats` | Bounded production shell command policy |
| `verify-env.bats` | Environment checks |
| `verify-pr.bats` | Change-class classifier fixtures (ADR-016) |
| `weekly-classifier.bats` | Weekly review classifier behavior |

Files may contain multiple focused `@test` cases or one inlined historical
harness while it is split incrementally. They must not invoke a removed external
test wrapper.

## Running

```bash
# Run fast verification (prerequisites and structural repository checks)
scripts/verify-local.sh

# Run complete verification (one full Bats suite plus structural checks)
scripts/verify-local.sh --full

# Run only the Bats component for targeted diagnosis
bats scripts/tests/

# Run one file
bats scripts/tests/verify-env.bats

# Parallel execution (requires GNU parallel — apt: parallel)
bats --jobs 12 scripts/tests/

# TAP output (default)
bats --tap scripts/tests/
```

## Installation

```bash
# Supported Linux verification prerequisites, including pinned uv/uvx
scripts/install-codespace-tools.sh --profile verification

# macOS
brew install bats-core parallel
bats --version  # must be 1.7.0 or newer
```

The canonical tool manifest pins Bats 1.12.0 and requires Bats 1.7.0 or newer. CI installs its
verification profile through `scripts/install-codespace-tools.sh`, then runs the
intentional full gate. The fast local runner does not invoke full Bats.

## Conventions

- Name tests for observable behavior rather than an implementation phase.
- Keep fixtures local, deterministic, and independent of network access.
- Add the failing fixture before changing the behavior it protects.
- Per-test timeout is set at **file-load time** via top-level `export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"` (5 min). Setting `BATS_TEST_TIMEOUT` inside `setup()` is a no-op — bats reads it in the parent process before forking the subprocess. Override per-run with `BATS_TEST_TIMEOUT=600 bats scripts/tests/`.
- No bats helper libraries are required. Add one only when repeated assertion
  code justifies the dependency.
