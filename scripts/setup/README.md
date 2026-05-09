# scripts/setup/

Modules sourced by [`scripts/setup.sh`](../setup.sh) in lexical order. Each
module owns one phase of project bootstrap and is independently re-runnable.

## Module ordering

| Module | Phase | Notes |
|---|---|---|
| `00-detect-repo.sh` | Resolve `FULL_REPO` from env/git remote; rewrite `.github/ISSUE_TEMPLATE/config.yml` placeholder. | Honors `GH_REPO` / `GITHUB_REPOSITORY` env overrides. |
| `10-env-file.sh` | Copy `.env.example` → `.env` if missing. | Idempotent — never overwrites an existing `.env`. |
| `20-install-dependencies.sh` | `npm ci` / `pip install` for declared manifests; database-migration stub. | DB block is template scaffolding for project customization. |
| `30-build.sh` | Run `npm run build` if `package.json` declares a build script. | Logs "No build step configured" otherwise. |
| `40-ensure-labels.sh` | Probe `gh auth`, resolve `FULL_REPO` fallback, `export GH_REPO`, create pipeline labels. | Sets shared gating vars (`_pipeline_setup_skip_reason`, `_gh_auth_ok`) consumed by 50/60. |
| `50-ensure-variables.sh` | `gh variable set` for `MAX_COPILOT_*`, `PR_RESOLVE_MAX_ROUNDS`. | No-ops when 40 requested skip. Includes one-time `MAX_COPILOT_DAILY` 20→10 migration. |
| `60-check-secrets.sh` | Report presence of `CLAUDE_PAT`, `ANTHROPIC_API_KEY` (repo + org tiers). | Cannot read values; presence-only. |
| `70-verify-env.sh` | Delegate to `scripts/verify-env.sh`. | Final gate. |

## How the modules are loaded

`setup.sh` sources each `[0-9][0-9]-*.sh` module in lexical order with
`source` (not exec), so they share environment. `scripts/lib/logging.sh`
(providing `log_step`, `log_info`, `log_warn`, `log_error`) is sourced once
by `setup.sh` before the module loop, so every module can call those
helpers directly.

## Running a single module

For debugging:

```bash
# From repo root
source scripts/lib/logging.sh
source scripts/setup/40-ensure-labels.sh
```

`40-ensure-labels.sh` and downstream modules require `FULL_REPO` to be set
(or detectable) — source `00-detect-repo.sh` first if you're starting from
a clean shell.

## Adding a new module

1. Choose a two-digit prefix that places the module at the right point in
   the lexical order (use `05`, `15`, `25`, etc. for insertion).
2. Document the module in the table above.
3. Use `log_step` for the section banner and `log_info` / `log_warn` /
   `log_error` from `scripts/lib/logging.sh` for output.
4. Make the module re-runnable. `setup.sh` is expected to be safe to run
   repeatedly.
