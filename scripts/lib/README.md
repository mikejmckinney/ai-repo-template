# scripts/lib/

Shared shell helpers sourced by `test.sh`, `scripts/setup.sh`, and the other
top-level shell entry points. See issue #255 for the modularization plan.

## Files

| File | Provides | Sourced by |
|---|---|---|
| `logging.sh` | Color vars (`RED`/`GREEN`/`YELLOW`/`BLUE`/`NC`) and `log_info`/`log_warn`/`log_error`/`log_step` printf helpers. | `scripts/setup.sh`, `scripts/db-reset.sh`, `scripts/sandbox-bootstrap.sh`, `scripts/verify-env.sh` |
| `assertions.sh` | `PASS`/`FAIL`/`WARN` counters and `pass`/`fail`/`warn` helpers used by verification scripts. Depends on `logging.sh` color vars. | `test.sh`, `scripts/verify-env.sh` |
| `jq/` | Standalone jq filter scripts and their fixtures (issue #229). | Workflows + `scripts/test-jq-filters.sh`. |

## Conventions

- Each lib file is sourceable on its own. None of them call `set -e`/`set -u`
  — those are caller policy.
- `logging.sh` uses unconditional ANSI escape codes. Scripts that need
  tty-aware colors (e.g., `scripts/closeout.sh`) keep their own gated block
  and do not source `logging.sh`.
- `assertions.sh` initializes counters with `: "${PASS:=0}"` so callers that
  pre-set the counters keep their values.

## Out of scope (future phases)

- `github.sh` (gh CLI wrappers) — deferred until issue #255 Phase 4c
  modularizes `setup.sh`, when the inline `gh label`/`gh variable` calls
  become natural extraction candidates. Today there are no named gh
  wrapper functions to extract.
- Bats test framework migration — issue #255 Phase 4b.
