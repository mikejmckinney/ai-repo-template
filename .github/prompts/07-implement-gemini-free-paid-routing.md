---
description: Add Gemini free/paid tier routing and benchmark cost-basis metadata on main.
agent: agent
---

# Prompt: Implement Gemini free-tier / paid-tier routing and benchmark cost-basis metadata

You are implementing a repo-local Gemini / Antigravity routing and cost-accounting improvement in `mikejmckinney/ai-repo-template` on branch **`main`** (after Phase A benchmark merge).

**Prerequisite:** Post-merge retro v2 ([#426](https://github.com/mikejmckinney/ai-repo-template/issues/426), `05-postmerge-retro-daily-v2.md`) must be merged and smoke-tested before starting this prompt.

## Start-state and required repo workflow

1. Start from a fresh, up-to-date checkout of `main`:

   ```bash
   git fetch origin
   git checkout main
   git pull --ff-only origin main
   git status --short
   ```

2. Read the startup contract and rule catalog before editing:

   ```text
   AGENTS.md
   .context/rules/process_session_start.md
   .context/rules/README.md
   ```

3. Read these benchmark-specific files before implementation:

   ```text
   .context/benchmarks/model-roi/README.md
   .context/benchmarks/model-roi/benchmark-runbook.md
   .context/benchmarks/model-roi/grading/README.md
   .context/benchmarks/model-roi/results/agent-roi-benchmark-results.md
   scripts/benchmark/adapters/gemini-cli.sh
   scripts/benchmark/lib.sh
   scripts/benchmark/doctor.sh
   scripts/benchmark/Makefile
   ```

4. Keep this work scoped to Gemini / Antigravity routing, auth/billing metadata, and benchmark cost-basis reporting. Do **not** implement the Class C benchmark in this PR. Do **not** change the canonical scoring rubric except to add metadata fields and documentation for Gemini cost-basis reporting.

## Background / rationale

The benchmark should continue to use **counterfactual paid-tier token pricing** as the primary ROI numerator/denominator basis for Gemini/Antigravity rows so rows are comparable across platforms and durable if free-tier quotas change. However, actual operations may use Gemini OAuth / Code Assist / IDE-integrated / Free tier access where the cash cost is currently zero until quota/rate limits are hit.

Implement a router and metadata model that supports both views:

```text
benchmark_roi = score / counterfactual_paid_cost_usd
cash_roi      = score / actual_billed_cost_usd_or_allocated_quota_cost
```

Primary benchmark tables must continue to use `counterfactual_paid_cost_usd` unless a future ADR explicitly changes this.

Official facts to verify before coding:

- Gemini API pricing distinguishes Free, Paid, and Enterprise tiers. The Free tier has free input/output tokens and says content is used to improve Google products; the Paid tier has higher rate limits, context caching, Batch API, advanced model access, and content not used to improve Google products.
- Gemini API paid pricing must be calculated from the **observed backend model**, not the requested alias. In current docs, examples include `gemini-3.5-flash`, `gemini-3.1-flash-lite`, and `gemini-3-flash-preview` with different paid rates.
- Gemini API rate limits are measured across requests per minute (RPM), tokens per minute (TPM), and requests per day (RPD). Usage is evaluated against each limit; rate limits apply per project, not per API key; RPD resets at midnight Pacific time.
- Gemini CLI documents three auth paths: Google OAuth sign-in, Gemini API key, and Vertex AI. OAuth has documented free usage; API key is best when specific model control or paid-tier access is needed; Vertex AI is best for enterprise / production workloads.

When in doubt, refresh the official Google docs before hard-coding rates, auth-mode assumptions, or limits.

## Implementation goals

### Goal 1 — Add an explicit Gemini routing wrapper

Add a small, deterministic wrapper that can route Gemini CLI calls through a declared policy:

```text
scripts/ai/gemini-router.sh
scripts/ai/gemini_quota_ledger.py
scripts/ai/gemini-auth-profiles.example.env
```

The wrapper should support these modes:

| Mode | Behavior |
|---|---|
| `free-only` | Try free/OAuth/IDE-integrated/API-key-free profile only. If rate-limited, exit with a clear quota-deferred status. |
| `free-then-paid` | Try free first; if rate-limited and paid profile is configured and task is allowed to use paid, retry once with paid. |
| `paid-only` | Use paid profile from the start. |
| `benchmark-paid-equivalent` | Run using configured auth, but emit metadata that ROI cost basis is counterfactual paid-tier pricing. |

The wrapper should accept at minimum:

```bash
scripts/ai/gemini-router.sh \
  --mode free-then-paid \
  --model gemini-3.1-flash-lite \
  --prompt-file /path/to/prompt.md \
  --out /path/to/agent-output.jsonl \
  --stderr /path/to/stderr.log \
  --metadata-out /path/to/gemini-routing.json \
  --output-format json
```

Keep flags simple and POSIX-friendly. Do not require jq for routing, but use it when available for richer metadata extraction.

The wrapper should:

1. Detect auth mode and profile:
   - IDE-integrated / Antigravity-ish env when `GEMINI_CLI_IDE_SERVER_PORT` and `GEMINI_CLI_IDE_AUTH_TOKEN` are present.
   - OAuth / Google sign-in when no API key is configured and Gemini CLI can run.
   - API-key free vs paid by explicit env variables, not by guessing.
   - Vertex AI when `GOOGLE_GENAI_USE_VERTEXAI=true` or related Vertex env is set.
2. Record observed auth mode in metadata.
3. Detect likely rate-limit failures from exit code and stderr/stdout patterns such as `429`, `RESOURCE_EXHAUSTED`, `Resource exhausted`, `rate limit`, `quota`, or `Requests per day`.
4. Retry paid only when mode is `free-then-paid`, paid profile is configured, and the request is not marked sensitive/private/free-only.
5. Never silently fall back to paid. Record `fallback_to_paid: true`, the reason, and which free profile failed.
6. Always write routing metadata even on failure.

### Goal 2 — Add a quota / usage ledger

Add `scripts/ai/gemini_quota_ledger.py` with a simple local JSON ledger under a gitignored path, for example:

```text
scripts/ai/.gemini-router-ledger.json
```

The ledger should not be the source of truth for rate limits; it is a best-effort local throttle and audit record. Handle real `429` / quota errors as authoritative.

Required ledger fields per day/profile/model:

```json
{
  "date_pacific": "2026-06-08",
  "profile": "free-oauth",
  "model_requested": "gemini-3.1-flash-lite",
  "model_observed": "gemini-3.1-flash-lite",
  "requests": 3,
  "input_tokens": 123456,
  "output_tokens": 7890,
  "total_tokens": 131346,
  "rate_limit_errors": 1,
  "fallbacks_to_paid": 0,
  "last_reset_estimate": "2026-06-09T00:00:00-07:00"
}
```

Subcommands:

```bash
python3 scripts/ai/gemini_quota_ledger.py record --metadata /path/to/gemini-routing.json
python3 scripts/ai/gemini_quota_ledger.py summary
python3 scripts/ai/gemini_quota_ledger.py reset --date-pacific YYYY-MM-DD
```

The metadata extraction should understand Gemini CLI JSON output where possible, including nested `.stats.models[*].tokens` and response metadata where present. It should tolerate missing fields.

### Goal 3 — Add profile configuration without committing secrets

Add:

```text
scripts/ai/gemini-auth-profiles.example.env
```

Example contents should show shape only:

```bash
# Free / individual / OAuth / IDE-integrated profile
GEMINI_ROUTER_FREE_PROFILE=oauth
GEMINI_FREE_ALLOW_SENSITIVE=false

# Paid profile. Do not commit real keys.
GEMINI_ROUTER_PAID_PROFILE=api-key-paid
GEMINI_PAID_API_KEY=replace-me
GEMINI_PAID_PROJECT=replace-me

# Default routing policy
GEMINI_ROUTER_MODE=free-only
GEMINI_ROUTER_RATE_LIMIT_FALLBACK=paid
GEMINI_ROUTER_RESET_TZ=America/Los_Angeles
```

Update `.gitignore` as needed so local profile files and ledgers are ignored:

```text
scripts/ai/gemini-auth-profiles.env
scripts/ai/.gemini-router-ledger.json
scripts/ai/.gemini-router-ledger.*.json
```

Do not commit credentials or personal project IDs.

### Goal 4 — Integrate metadata with benchmark Gemini adapter

Update `scripts/benchmark/adapters/gemini-cli.sh` to optionally use the router when explicitly enabled:

```bash
GEMINI_ROUTER_ENABLED=1
GEMINI_ROUTER_MODE=benchmark-paid-equivalent
```

Default behavior should remain backward-compatible when `GEMINI_ROUTER_ENABLED` is unset.

When enabled, the adapter should write:

```text
<run-outdir>/gemini-routing.json
```

The metadata should include:

```json
{
  "schema_version": "gemini-routing.v1",
  "router_mode": "benchmark-paid-equivalent",
  "auth_mode": "ide-integrated|oauth|api-key-free|api-key-paid|vertex|unknown",
  "billing_mode": "free|paid|ide-integrated|oauth|unknown",
  "privacy_tier": "free-content-may-train|paid-content-not-used-to-improve-products|unknown",
  "model_requested": "gemini-3.5-flash",
  "model_observed": "gemini-3-flash-preview",
  "fallback_to_paid": false,
  "fallback_reason": null,
  "rate_limit_error": false,
  "actual_billed_cost_usd": 0.0,
  "counterfactual_paid_cost_usd": null,
  "cost_basis_for_roi": "counterfactual_paid",
  "tokens": {
    "input": null,
    "cached": null,
    "output": null,
    "thoughts": null,
    "total": null
  }
}
```

Do not require exact token fields to be present for every auth mode. When Gemini CLI JSON stats are available, fill them. When missing, preserve nulls and note the limitation.

### Goal 5 — Add counterfactual paid-cost calculation hooks

Add helper logic, preferably in Python under `scripts/benchmark/`, that can compute Gemini counterfactual paid cost from observed model + token stats.

Suggested file:

```text
scripts/benchmark/gemini_cost_basis.py
```

Required behavior:

1. Input: `agent-output.jsonl` and optional `gemini-routing.json`.
2. Parse observed model(s) from `.stats.models` when available.
3. Use observed backend model rates, not requested aliases.
4. Output:

   ```json
   {
     "schema_version": "gemini-cost-basis.v1",
     "model_costs": [
       {
         "model": "gemini-3-flash-preview",
         "input_tokens": 123,
         "cached_tokens": 0,
         "output_tokens": 456,
         "thought_tokens": 78,
         "counterfactual_paid_cost_usd": 0.00123,
         "rate_source_date": "YYYY-MM-DD"
       }
     ],
     "total_counterfactual_paid_cost_usd": 0.00123,
     "actual_billed_cost_usd": 0.0,
     "cost_basis_for_roi": "counterfactual_paid"
   }
   ```

5. Put rates in a single versioned table with a clear refresh note. Include at least current entries needed by this branch:
   - `gemini-3.5-flash`
   - `gemini-3-flash-preview`
   - `gemini-3.1-flash-lite`
   - `gemini-3.1-pro-preview` if used by existing benchmark rows

6. Add a visible note in docs that rates must be refreshed before publishing final benchmark conclusions.

Do not update historical cost tables silently. Preserve historical values unless explicitly running a documented ROI refresh.

### Goal 6 — Add benchmark result/reporting docs

Update:

```text
.context/benchmarks/model-roi/README.md
.context/benchmarks/model-roi/benchmark-runbook.md
.context/benchmarks/model-roi/grading/README.md
.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md
```

Document:

1. Primary ROI uses counterfactual paid-tier cost for Gemini rows.
2. Actual billed cost is a separate adoption/cash-flow metric.
3. Free-tier use is allowed only for public/non-sensitive tasks unless a maintainer explicitly approves it.
4. Free-tier content may be used to improve Google products; paid-tier content is not, per Google docs. Do not send sensitive/proprietary content through free-tier routing.
5. Rate limits are RPM/TPM/RPD per project, and free-tier routing should treat `429` / quota errors as authoritative.
6. Gemini CLI / Antigravity integrated auth may be observed in a developer environment, but benchmark automation must record the actual auth mode and not assume it is available everywhere.
7. Class C benchmark should run after this routing metadata exists, but Class C implementation is out of scope for this PR.

### Goal 7 — Add deterministic checks

Add or update checks so this work is tested without making paid/free model calls.

Suggested check:

```text
scripts/checks/169-gemini-routing.sh
```

The check should validate:

1. Router script exists and has valid bash syntax.
2. Ledger script exists and has valid Python syntax.
3. Example env file exists and contains no real-looking secrets.
4. `gemini-routing.json` schema fixture validates.
5. Cost-basis helper can parse a small fixture `agent-output.jsonl` and compute expected cost.
6. Router can run in a mocked mode that simulates:
   - free success
   - free 429 then paid fallback
   - free 429 with no paid fallback allowed
   - paid-only

If adding a JSON schema, place it under:

```text
.context/benchmarks/model-roi/grading/gemini-routing.schema.json
.context/benchmarks/model-roi/grading/gemini-cost-basis.schema.json
```

Update `test.sh` check sourcing if needed so the new check runs with the rest of the suite.

### Goal 8 — Do not widen scope

Do not implement:

- Class C benchmark itself.
- Spec Kit integration.
- PR advisory review workflows.
- AGENTS/rules decomposition beyond what is already in branch.
- Broad model routing for non-Gemini tools.
- Automatic paid fallback for sensitive/private tasks.

If you find issues outside scope, add a short “Opportunity notes” section in the PR body or final response.

## Privacy and safety policy

Implement conservative defaults:

```text
Default router mode: free-only
Default sensitive/private handling: paid-only or refuse free route
Default benchmark mode: benchmark-paid-equivalent
Default paid fallback: disabled unless explicitly enabled
```

The router must refuse free-tier routing when any of the following are true:

- `GEMINI_ROUTER_SENSITIVE=1`
- repo is private and no override is set
- task label or env marks customer data, secrets, compliance-sensitive, or proprietary content
- prompt path or diff includes obvious secret-bearing paths

At minimum, detect common secret-bearing paths:

```text
.env
*.pem
*.key
secrets/**
credentials/**
*.tfvars
```

Emit a clear message when free routing is refused:

```text
Gemini free-tier route refused because this task is marked sensitive/private. Use paid-only or override explicitly after confirming data policy.
```

## Acceptance criteria

A maintainer should be able to run:

```bash
./test.sh
bash scripts/checks/169-gemini-routing.sh
python3 scripts/benchmark/gemini_cost_basis.py --help
python3 scripts/ai/gemini_quota_ledger.py summary
```

Expected outcomes:

- No real Gemini API call is required by tests.
- No credentials are committed.
- Gemini routing metadata schema is documented and fixture-tested.
- Existing benchmark Gemini adapter still works when router is disabled.
- Router can be enabled explicitly for benchmark runs.
- Docs clearly separate actual billed cost from counterfactual paid cost.
- Results docs state that Gemini benchmark ROI should continue using counterfactual paid-tier pricing for fair cross-platform comparison.

## Final response requirements

When done, summarize:

1. Files changed.
2. How to use the router in each mode.
3. How Gemini benchmark ROI cost basis is now recorded.
4. How privacy-sensitive tasks are protected from free-tier routing.
5. Verification commands and results.
6. Any follow-up opportunities, limited to high-impact items only.
