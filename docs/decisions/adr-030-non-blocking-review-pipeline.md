# ADR-030: Non-blocking LLM review pipeline (advisory, daily retro, weekly review)

## Status

Accepted (finalize stage retired by ADR-031)

## Date

2026-06-12

## Context

The combined agent prompt pack v2 (PRs 2–4 on `main`) added three **opt-in, non-blocking** GitHub Actions workflows that use Cursor/Gemini runners for LLM-assisted review. They sit alongside existing formal bot reviews (Copilot, Gemini Code Assist) and blocking human gates — they do **not** replace plan-gate, diff-gate, or `claude-fix`.

Prior to pack PR 4, post-merge retro created **one GitHub issue per finding**, which produced operator noise during dogfood (umbrella [#425](https://github.com/mikejmckinney/ai-repo-template/issues/425)). PR [#427](https://github.com/mikejmckinney/ai-repo-template/pull/427) refactors post-merge retro into a **daily batch**: umbrella issue + draft fix PR.

No ADR previously documented the three-phase pipeline, trigger model, or the v1→v2 post-merge output change. This ADR records the durable **why**; workflow behavior is specified in [`docs/guides/agent-pipeline.md`](../guides/agent-pipeline.md).

## Decision

We adopt a **three-stage non-blocking review pipeline** on `main`:

| Stage | Workflow | Opt-in | When | Output |
|---|---|---|---|---|
| **1. Advisory** | `agent-advisory-review.yml` | `ai-review:live` (+ optional `ai-review:full` for depth) | During PR life (incl. draft); on push/label | Single sticky PR comment `<!-- ai-advisory-review:v1 -->` |
| **2. Post-merge retro** | `agent-postmerge-retro.yml` | **None** (daily batch; no label gate) | `schedule: 0 6 * * *` UTC + `workflow_dispatch` | One **umbrella issue**/day + optional **draft fix PR** `retro/fix-YYYY-MM-DD` |
| **3. Weekly repo review** | `agent-weekly-review.yml` | **None** (weekly batch; no label gate) | `schedule: 0 7 * * 0` UTC (Sunday) + `workflow_dispatch` | One **umbrella issue**/ISO week + optional **draft fix PR** `weekly/fix-YYYY-Www` |

Shared properties:

- **Providers:** `POSTMERGE_RETRO_PROVIDER` / `WEEKLY_REVIEW_PROVIDER` default
  `auto` attempts Claude first, then OpenCode, Cursor, and retained
  Antigravity/Gemini adapters. `ADVISORY_REVIEW_PROVIDER=auto` uses the
  separately amended pre-merge model cascade below. Daily and weekly fix
  cascades remain Claude-free.
- **Scripts:** `scripts/workflows/advisory-review/` (LLM runners), `scripts/workflows/pr-feedback/` (finalize collect), `scripts/workflows/postmerge-retro/` (retro + daily batch), `scripts/workflows/weekly-review/` (weekly full-repo scan + fix).
- **Lifecycle libraries:** advisory, daily, and weekly adapters share the versioned AP11 observation validator and priority derivation in `scripts/workflows/lib/finding_priority.py`; daily and weekly also share provider dispatch, umbrella issue transport/reference handling, superseded-path detection, and batch-fix publication. Cadence-specific prompts, templates, markers, authority, and metadata hooks remain explicit.
- **Non-goals:** No auto-merge of fix PRs; no automatic `claude-fix`; no ADR/context-pack file edits in retro jobs; no formal PR review submission from advisory/finalize.

### Post-merge retro v2 (supersedes v1 trigger/output)

**Triggers (Option C):** cron + `workflow_dispatch` only. **Removed:** `pull_request: closed` and retro label workflow gates (`retro-review`, `retro:adr`, etc.). The obsolete retro labels are retired and do **not** gate automation.

**Batch behavior:**

1. List all PRs merged to `main` in the rolling last 24 hours.
2. Per-PR evidence collection + LLM retro → merge into `daily-retro.json`.
3. Create or **append** one umbrella issue per calendar day (`<!-- postmerge-retro:daily:YYYY-MM-DD -->`).
4. If findings &gt; 0: second LLM pass opens/updates a **draft** fix PR implementing **all** findings; human or agent verifies before merge.

**Idempotency:** Later runs the same day **append** new PR rows to the umbrella; they do not skip the job because the daily marker exists.

**Empty windows:** No merges, or zero findings → skip umbrella and/or fix PR as appropriate.

**Verification class:** `schedule` + `workflow_dispatch` → default-branch-only workflow ([ADR-016](./adr-016-pre-merge-verification-gate.md)); prove in sandbox before merging upstream ([ADR-029](./adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md)).

### Weekly repo review (stage 4)

**Triggers:** Sunday **07:00 UTC** cron + `workflow_dispatch` only (offset from daily retro at 06:00 UTC to reduce concurrent load). **Scope:** static **full-repo** health scan on `main` — not PR-scoped.

**Batch behavior:**

1. Collect run metadata (HEAD SHA, run week) + inject **`full`** context profile via `prompt_helpers.py select-context` (context pack only — no path-trigger expansion).
2. Single LLM pass with **repository read access** (Cursor `local.cwd`; Antigravity when `auto` lacks Cursor) → `weekly-review.json`. New findings use the shared `triage_version: 2` AP11 observations; automation validates them, derives `priority_band`, and rejects model-authored `severity` or priority.
3. Create or **append** one umbrella issue per ISO week (`<!-- weekly-review:YYYY-Www -->`). Each finding appears in a compact triage summary table and a detailed block containing its full body, `repo-*` key, reproduction steps, and evidence links pinned to scan HEAD.
4. If findings &gt; 0: second LLM pass opens/updates a **draft** fix PR `weekly/fix-YYYY-Www`; native GitHub issue link via `Fixes #N` in PR body (`scripts/workflows/lib/link-fix-pr-to-issue.sh`).

**Idempotency:** Re-runs the same ISO week **append** new finding blocks by dedupe marker (`<!-- weekly-review:finding:repo-… -->`); they do not skip because the weekly marker exists.

**Smoke-test inputs:** `workflow_dispatch` may pass explicit `run_week` / `run_date` (e.g. sandbox `2099-Www` + far-future dates) to isolate idempotency keys from production ISO weeks. Production cron computes `RUN_WEEK` from UTC `RUN_DATE` via `resolve-run-week.sh`.

**Empty windows:** Zero findings → skip umbrella and fix PR (same as daily retro).

**Deferred routing parity:** Weekly review does not copy the per-PR evidence coverage or adaptive routing model. Add weekly coverage warnings/routing only when explicit weekly context caps exist or observed truncation provides a concrete trigger.

## Options Considered

### Option 1: Keep v1 per-PR close trigger + per-finding issues

- **Pros:** Immediate retro on labeled merges; granular issues.
- **Cons:** Noisy; duplicate work when daily batch added; label ceremony.

### Option 2: Daily batch only (chosen for stage 3)

- **Pros:** One umbrella + one draft fix PR; simpler operator model; no label gates.
- **Cons:** Up to ~24h delay; fix PR may be large; requires sandbox proof pre-merge.

### Option 3: Prompt-hint or label-gated daily batch

- **Pros:** Cheaper runs on quiet days.
- **Cons:** Reintroduces label discipline; rejected for v2.

## Consequences

### Positive

- Single documented pipeline for AP8 non-blocking LLM review.
- Post-merge output matches operator preference (umbrella + draft fix PR).
- Reuses shared evidence collection and LLM runners across stages.

### Negative

- Daily fix PRs can be large; review load shifts to morning batch review.
- Sandbox verification required for workflow changes ([ADR-016](./adr-016-pre-merge-verification-gate.md)).
- Legacy `postmerge-retro-create-issues.sh` retained but not used by v2 daily path.

### Neutral

- Provider routing can evolve independently after benchmark and sandbox evidence supports a change.

## Amendment 2026-07-14 — OpenCode runtime and GitHub MCP

Issue [#480](https://github.com/mikejmckinney/ai-repo-template/issues/480)
moves all three stages to an OpenCode-first runtime without moving evidence or
publication authority into the agent.

- The production adapter uses pinned `@opencode-ai/sdk/v2` sessions. Headless
  CLI remains a diagnostic surface, not the workflow protocol.
- The public-CI model cascade is `openrouter/z-ai/glm-5.2@preset/default`, then
  `openrouter/minimax/minimax-m3@preset/default`. The adapter validates model
  text against the cadence schema, sends one corrective prompt, and then
  advances models. OpenCode 1.18.0's `format` path is not a correctness boundary
  because its synthetic output tool and `retryCount` are unreliable (upstream
  [issue #25430](https://github.com/anomalyco/opencode/issues/25430)).
  Subscription-backed `openai/gpt-5.6-sol` remains an
  interactive local and `multi-model-consensus` model because OpenAI excludes personal
  ChatGPT-managed credentials from public/open-source CI automation.
- Jobs run on GitHub-managed `ubuntu-latest`, matching the established Cursor
  workflow pattern. Node 22 is configured with `actions/setup-node`, and
  `npm ci` installs pinned OpenCode and SDK `1.18.0` from the committed lockfile.
- Agent-directed GitHub reads use a dedicated `OPENCODE_GITHUB_TOKEN` through
  GitHub's hosted MCP endpoint with read-only and lockdown headers and only the
  `repos`, `issues`, `pull_requests`, and `actions` toolsets.
- Deterministic scripts retain pagination, evidence coverage, schema validation,
  dedupe, comments, issues, commits, pushes, and draft-PR publication. The
  OpenCode child process is launched without `GITHUB_TOKEN`, `GH_TOKEN`,
  `CLAUDE_PAT`, or `SANDBOX_BOOTSTRAP_TOKEN`.
- Review profiles deny edits, shell, web, and subagents. Fix profiles allow edits
  but deny shell because command allowlists cannot prevent an editable script from
  reading inherited model or MCP credentials. Every model attempt runs in a
  disposable detached worktree, and the deterministic controller runs `./test.sh`
  without credentials. Only the first schema-valid, verified patch is promoted.
- Cursor, Antigravity, and Gemini remain explicit rollback providers during the
  rollout.

## Amendment 2026-07-16 — Retrieval-first evidence and durable fallback

[Issue #485](https://github.com/mikejmckinney/ai-repo-template/issues/485)
corrects two gaps exposed by
[run 29477823468](https://github.com/mikejmckinney/ai-repo-template/actions/runs/29477823468):

- Tool-capable full-evidence review receives a deterministic inventory of
  addressable local and GitHub sources instead of injected source bodies and
  capped diff/HEAD excerpts. The inventory remains the completeness control;
  agent retrieval does not replace coverage accounting.
- Ephemeral evidence lives inside ignored repository `.artifacts/` so the
  read-only OpenCode profile can inspect it without external-directory access.
- `auto` attempts available analysis providers in OpenCode, Cursor, then Gemini
  order. A failed provider advances to the next provider rather than retrying a
  bounded version of the same incomplete review.
- Daily per-PR failures become explicit sidecars and batch metadata. They do not
  prevent successful PR results, final daily JSON, or workflow artifacts from
  surviving.
- Empty Cursor results include sanitized status/error metadata. Interactive
  process termination uses prospective lifecycle and signal diagnostics rather
  than attributing graceful disposal to model output limits without evidence.

## Amendment 2026-07-17 — Cursor Grok primary review routing

Review automation now prefers Cursor `cursor-grok-4.5-medium` when Cursor
credentials are available, then falls back to the retained OpenCode and Gemini
adapters. This supersedes only the provider order established by the 2026-07-16
amendment; the OpenCode isolation, retrieval, validation, and durable-fallback
controls remain unchanged. Composer 2.5 remains an explicit override rather
than the workflow default.

## Amendment 2026-07-21 - Access-only Sol routing on hosted runners

[Issue #503](https://github.com/mikejmckinney/ai-repo-template/issues/503)
supersedes the 2026-07-17 provider order and the 2026-07-14 exclusion of
subscription-backed Sol for this trusted private repository.

- A maintainer-run Codespace utility copies the current OpenAI access token,
  expiration, and account ID into `OPENCODE_OPENAI_AUTH`. It replaces the real
  refresh token with `ci-refresh-disabled`; Actions cannot refresh or persist a
  rotated credential.
- Credential content is mapped to `OPENCODE_AUTH_CONTENT` only on invocation
  steps. Preflight rejects malformed or refresh-enabled content and omits Sol
  unless the token outlives the complete job timeout plus 15 minutes.
- OpenCode attempts `openai/gpt-5.6-sol`, when eligible, then
  `openrouter/moonshotai/kimi-k3@preset/consensus`. Provider fallback next uses
  Cursor `cursor-grok-4.5-medium`; existing Antigravity/Gemini rollback adapters
  remain available where configured.
- Advisory accepts the existing same-repository branch trust boundary already
  used for model credentials. Fork PRs remain excluded.
- Review output must pass cadence validation. Every fix provider runs inside a
  disposable worktree, controller verification receives no model, OAuth,
  publisher, or sandbox credentials, and only a verified patch is promoted.

### Amendment 2026-08-01 — Explicit fail-closed fix promotion stages

The shared daily and weekly fix controller does not rely on Bash `errexit`
inside conditional command lists. It captures provider invocation, optional
Gemini application, candidate verification, fix-verification validation, and
outcome-evidence validation separately; any nonzero status stops that attempt
before later stages or patch promotion. A credential-free clean-HEAD baseline is
recorded separately from candidate verification, and intent-to-add registration
makes candidate-created files visible to tracked-file-derived fixtures before
the candidate command runs. OpenCode retains edit access with Bash denied.

### Amendment 2026-08-01 — Capability routing and controller evidence authority

Daily and weekly findings now propose a typed verification environment and
repository-owned harness identifier. Only `isolated-worktree` with the
allowlisted `repository-test-suite` harness can enter automated implementation;
missing, invalid, Codespaces, external-state, and unsupported-runtime proposals
remain in umbrella output as human follow-ups. Free-form `repro_steps` are never
executed.

Fix providers supply implementation reasoning, harness proposals, and
dispositions but cannot certify execution. The controller reconstructs finding
identities from its canonical batch, replaces execution fields with immutable
baseline/candidate exit codes, and creates outcome evidence. Failed attempts
retain bounded redacted metadata, not raw responses or full patches, and both
fix workflows upload those diagnostics even when the fix step fails. Gemini gets
one bounded schema-correction retry before the attempt is discarded. OpenCode's
Bash denial and provider credential isolation remain unchanged.

### Amendment 2026-07-23 — Shared AP11 classifier across review surfaces

All new advisory, daily, and weekly model findings emit the normalized
`triage_version: 2` observation fields defined in the shared review contract.
Automation validates impact kind/magnitude, likelihood, scope, reversibility,
cost, confidence, uncertainty, and regression-guard value before deriving one
priority band. Advisory providers emit structured JSON; the deterministic
adapter renders the sticky Markdown comment and keeps every band non-blocking.
Formal/manual review uses the same classifier but applies its own authority only
after classification. Unversioned persisted daily/weekly records remain version
1 and retain their original decision table during reconstruction.

### Amendment 2026-08-01 — Model-specific pre-merge advisory cascade

[Issue #556](https://github.com/mikejmckinney/ai-repo-template/issues/556)
separates the label-gated pre-merge model order from the unchanged daily and
weekly provider cascade.

- Pre-merge `ADVISORY_REVIEW_PROVIDER=auto` attempts available candidates in
  this order: Claude Code `claude-opus-5` at medium effort, OpenCode
  `openai/gpt-5.6-sol` at medium effort, Cursor `cursor-grok-4.5-medium`, then
  OpenCode `openrouter/moonshotai/kimi-k3@preset/consensus`.
- Explicit `ADVISORY_REVIEW_PROVIDER=opencode` retains its Sol-then-Kimi
  internal fallback. Daily and weekly `auto` retain OpenCode, Cursor, and
  cadence-specific Antigravity/Gemini behavior.
- Each pre-merge candidate has a configurable outer timeout, defaulting to 300
  seconds plus a 10-second termination grace period, inside the unchanged
  20-minute advisory job budget.
- Claude Code is pinned to `2.1.220` and receives only repository read/search
  plus web fetch/search tools. OpenCode review profiles allow the same research
  capability, while Bash, edits, subagents, and external-directory access remain
  denied. OpenCode fix profiles remain offline, and this amendment grants no web
  access to other fix providers. External content is evidence rather than
  executable instruction, and prompts prohibit transmitting repository content
  through URLs, search queries, or forms. Unrestricted review egress retains a
  residual risk that repository or web content could induce an
  outbound request containing private source. The maintainer accepts that risk
  for read-only review because same-repository gating, credential isolation,
  non-blocking authority, and deterministic publication limit likelihood and
  impact. OpenCode web search uses Exa AI's unauthenticated hosted service for
  OpenCode candidates only. It does not constrain Claude's separate
  `WebFetch` and `WebSearch` tools. Downstream repositories that reject this
  accepted egress policy must intentionally change the review profile, workflow,
  and matching invariant rather than relying on an unverified environment-value
  opt-out. A maintainer-generated `claude setup-token` value is stored as
  `CLAUDE_OAUTH_SECRET`, mapped to `CLAUDE_CODE_OAUTH_TOKEN` only for provider
  execution, and isolated from publisher and other provider credentials.
- Model-specific candidate names are internal routing details. Snapshot memory
  continues to record stable observed providers so Sol and Kimi remain
  compatible with `opencode` incremental-review history.

### Amendment 2026-08-02 — Direct-source pre-merge retrieval

[Issue #556](https://github.com/mikejmckinney/ai-repo-template/issues/556)
removes copied evidence from pre-merge model prompts after every automatic
candidate gained repository and read-only GitHub access.

- The prompt retains only the review/output contract and invocation coordinates.
  It does not embed `AGENTS.md`, shared lenses, task-triggered governance bodies,
  the PR body, changed-file lists, prior snapshots, or capped diff excerpts.
- Claude, OpenCode, and Cursor run from the checked-out PR head and retrieve the
  current issue, PR, discussion, checks, diff, startup instructions, shared
  lenses, and relevant files directly. Claude and Cursor use the same dedicated
  `OPENCODE_GITHUB_TOKEN` and hosted MCP lockdown headers as OpenCode; the token
  is exposed to them only as `ADVISORY_GITHUB_TOKEN` for the candidate process.
- Claude uses strict ephemeral MCP configuration and an explicit
  `mcp__github_read__*` allowlist. Cursor uses inline HTTP MCP configuration,
  disables ambient setting sources, and runs in plan mode. Cursor's local
  headless SDK does not treat plan mode as a hard tool-permission boundary and
  may still expose shell or workspace-write tools. The maintainer accepts this
  residual risk because the candidate is same-repository, non-blocking,
  time-bounded, and isolated from publisher credentials.
- Pre-merge Gemini and Antigravity overrides are retired because they do not
  satisfy the direct-source contract. Daily and weekly provider routing,
  adapters, and fix behavior remain unchanged.
- `ai-review:full` now forces a full base-to-head review range rather than a
  larger injected context pack. Snapshot normalization reports range size rather
  than unobservable model-consumption coverage, and records the exact reviewed
  head only when the provider returns `evidence_retrieved: true` after required
  source retrieval. A false or missing value advances the cascade.
- Claude receives a generated session ID and persists its local JSONL during the
  candidate attempt. Invocation, metadata, or output-validation failure copies
  that session into an authenticated Actions artifact retained for seven days;
  known workflow credential values are redacted and successful sessions are not
  uploaded. The artifact is not printed in logs and may contain private
  repository evidence or tool results, so it is restricted operationally to
  trusted repository collaborators.

### Amendment 2026-08-02 — Claude-first recurring analysis

[Issue #560](https://github.com/mikejmckinney/ai-repo-template/issues/560)
extends the established read-only Claude review adapter to daily and weekly
analysis without changing fix authority.

- Daily `auto` attempts Claude Opus 5 Medium, OpenCode, Cursor, then Gemini.
  Weekly `auto` uses the same first three providers, followed by optional
  Antigravity and Gemini. Explicit daily and weekly Claude overrides are
  supported; inherited Claude selection is remapped to the existing automatic
  cascade in both fix modes.
- Claude remains fixed to `claude-opus-5` with medium effort and receives only
  `Read`, `Glob`, `Grep`, `WebFetch`, `WebSearch`, and the locked-down read-only
  GitHub MCP. The existing subscription OAuth secret is scoped to analysis
  execution and removed from every non-Claude provider process.
- Daily full-evidence success requires the observed Claude tool trace to cover
  the finite per-PR evidence inventory. Weekly success requires observed
  repository reads and path-backed findings, without claiming exhaustive
  repository coverage.
- Invocation, metadata, schema, or retrieval-validation failure advances the
  cadence cascade. A 900-second candidate timeout prevents a stalled Claude
  attempt from consuming the cadence job budget. Failed Claude sessions use
  collision-safe IDs in diagnostic-only sibling artifact roots and the same
  redacted seven-day lifecycle as pre-merge review; successful sessions create
  no transcript artifact.
- Daily and weekly fix providers, credentials, disposable-worktree isolation,
  verification, and promotion behavior are unchanged.

## Implementation

- [x] Pack PRs 2–4 on `main` (advisory, finalize, retro v1).
- [x] PR #427 — retro v2 daily batch + AGENTS.md v25 compaction/profile rules.
- [x] Sandbox smoke of `agent-postmerge-retro.yml` on `ai-repo-template-sandbox` — end-to-end with canary PR #42 (ADR-029 evidence on #427).
- [x] Automation templates: `.github/templates/postmerge-retro-umbrella.md`, `postmerge-retro-fix-pr.md`; resilient `agent-suggested` label; sandbox label bootstrap via `ensure-pipeline-labels.sh`.
- [x] Merge #427 after review.
- [x] Triage legacy umbrella [#425](https://github.com/mikejmckinney/ai-repo-template/issues/425) (2026-06-13 post-merge).
- [x] Sandbox smoke of `agent-weekly-review.yml` — [run 27516674507](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27516674507) (`2099-W05`, umbrella [#79](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/79), fix PR [#80](https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/80); detailed finding blocks + native link verified on PR #433 branch).
- [x] Merge PR [#433](https://github.com/mikejmckinney/ai-repo-template/pull/433) (weekly review + collector hardening) to upstream `main` (merged 2026-06-15).
- [x] Issue [#480](https://github.com/mikejmckinney/ai-repo-template/issues/480) — OpenCode-first amendment merged in [PR #481](https://github.com/mikejmckinney/ai-repo-template/pull/481).

## References

- [Agent pipeline guide § Post-merge retrospective](../guides/agent-pipeline.md)
- [Combined prompt pack v2 at its final retained commit](https://github.com/mikejmckinney/ai-repo-template/blob/57630c8bc3409798ca4844cc807b406d57108bd8/.github/prompts/agent-pr-prompts-combined-v2.md) — PRs 2–4
- [ADR-016 Pre-merge verification gate](./adr-016-pre-merge-verification-gate.md)
- [ADR-027 Opportunity feedback channel](./adr-027-opportunity-feedback-channel.md)
- [ADR-029 Sandbox dogfood evidence](./adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md)
- [ADR-031 Agent/model ROI benchmark policy](./adr-031-agent-model-roi-benchmark-policy.md) — monolithic default; model/context recommendations
- Issue [#426](https://github.com/mikejmckinney/ai-repo-template/issues/426), PR [#427](https://github.com/mikejmckinney/ai-repo-template/pull/427), PR [#433](https://github.com/mikejmckinney/ai-repo-template/pull/433)
