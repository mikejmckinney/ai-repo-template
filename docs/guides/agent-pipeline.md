# Agent Pipeline

ADR-031 defines a monolithic implementation and review lifecycle. One agent owns
routine implementation; CI blocks regressions; agents normally enable parallel
advisory review; daily and weekly review operate after changes reach `main`.

## Implementation

Use one implementing agent on a non-default branch. Fill the issue body's v2
plan block (or grandfathered v1 comment), create an empty bootstrap commit,
push, and open a linked draft PR before meaningful edits. Each changed turn
commits and pushes task-owned work before updating `agent-state:v1`; known-red
draft state is explicit and does not block checkpoint durability.

Issue assignment is operator-driven. The template does not provision a coding-agent
queue or automatically transition draft PRs.

## Advisory Review

`agent-advisory-review.yml` remains label-gated through `ai-review:live`, which
agents apply to every eligible same-repository task PR they create or claim. It
runs for same-repository open PRs, including drafts, on qualifying open,
reopen, synchronize, ready, and label events. Concurrency is keyed by PR and
`cancel-in-progress: true`, so implementation never waits for an older snapshot.

The workflow posts or updates one `<!-- ai-advisory-review:v1 -->` comment. It
cannot submit formal reviews, push commits, mutate labels, resolve threads,
change readiness, or block merge. Before completion, the implementing agent
compares an arrived snapshot's `Head` SHA with the current PR head and independently
verifies applicable findings. Missing, stale, running, or failed feedback never
blocks completion. Forks, `smoke-test` PRs, and repositories lacking the workflow,
label, provider credentials, or label-write permission are exempt and record why.
`ai-review:full` forces a full base-to-head refresh instead of an incremental
review; every mode retrieves evidence directly from the repository and GitHub.

Pre-merge `auto` attempts available model candidates in this order: Claude Code
`claude-opus-5` at medium effort, OpenCode `openai/gpt-5.6-sol` at medium effort,
Cursor `cursor-grok-4.5-medium`, then OpenCode
`openrouter/moonshotai/kimi-k3@preset/consensus`. Missing credentials omit only
their candidate. Explicit `ADVISORY_REVIEW_PROVIDER=opencode` retains the
internal Sol-then-Kimi cascade.

Pre-merge prompts contain only the review contract and invocation coordinates:
repository, pull request, expected head, base and diff-base SHAs, review basis,
and mode. They do not embed startup files, governance bodies, the PR body,
changed-file inventories, prior snapshots, or diff excerpts. Every automatic
candidate runs from the checkout and retrieves current repository and PR evidence
itself. Claude and Cursor receive the same dedicated read-only GitHub MCP as
OpenCode. Pre-merge Gemini and Antigravity overrides are unsupported; those
providers remain available only where the daily or weekly contracts retain them.

`ADVISORY_CANDIDATE_TIMEOUT_SECONDS` bounds each provider attempt; the default is
`300` seconds. A 10-second forced-termination grace period follows. This outer
candidate cap takes precedence over longer provider transport budgets so the
four-candidate cascade and publication remain within the 20-minute job.

Automation owns the snapshot's head, provider/model, review-range metadata, and hidden
`ai-advisory-memory:v1` payload. The visible findings are the provider-neutral
summary. Providers emit structured `triage_version: 2` observations; automation
validates the shared AP11 fields, derives the priority band, and renders the
table. Providers must also assert `evidence_retrieved: true`; a false or missing
value advances the cascade and writes no reviewed-head memory. Advisory authority
stays non-blocking for every band. An empty result says
`No findings identified at this head.` rather than rendering an empty table.
Compatible synchronize events review the accumulated
delta from the last completed reviewed head. Missing or invalid memory, readiness,
full mode, base changes, expected-provider changes, and non-ancestor history force
a full PR refresh. If an in-flight run is canceled, the last completed sticky
memory remains authoritative and the next delta spans every intervening commit.

## Blocking Pre-Merge Controls

Repository tests and lint/format checks are the blocking controls. Branch rulesets
must require their check names. Advisory, overlap reports, and retro outputs are
supporting evidence and never satisfy or replace deterministic CI.

## Daily Post-Merge Retro

`agent-postmerge-retro.yml` runs at 06:00 UTC and by manual dispatch. It reviews
merged PR evidence, writes one daily umbrella issue, and may publish a draft fix
PR. Only `should-fix` and `fix-now` findings with the typed
`isolated-worktree` / `repository-test-suite` capability enter automated
implementation. Findings requiring Codespaces, external state, secrets, or an
unsupported runtime remain visible human follow-ups without provider invocation.
Verification-only output opens no PR. Published PRs
must acquire a native GitHub Development-graph link to the umbrella issue; a
closing keyword without that relationship fails the job. Fix publication is
never auto-merged. The umbrella retains every non-superseded finding, while only
`should-fix` and `fix-now` findings enter the fix pass. A defer-only batch keeps
its review record and invokes no fix provider.

## Weekly Repository Review

`agent-weekly-review.yml` runs Sunday at 07:00 UTC and by manual dispatch. It
performs a static full-repository scan of `main`, writes one ISO-week umbrella,
and may publish a draft fix PR. The scan has a 120-minute job budget; its
separate fix job retains the 60-minute budget.

Daily and weekly adapters share provider routing, priority derivation,
supersession, umbrella transport, and batch-fix publication under
`scripts/workflows/lib/`. Their schemas, templates, markers, and evidence inputs
remain cadence-specific. New model output uses the same `triage_version: 2`
observation fields as advisory. Unversioned persisted daily/weekly records keep
the version 1 decision table during reconstruction; automation does not silently
reinterpret historical findings.

## OpenCode Runtime

Daily and weekly automation resolve `auto` in this order:

1. OpenCode when the runtime, `OPENCODE_GITHUB_TOKEN`, and
   `OPENROUTER_API_KEY` are available. It tries Sol first when a preflighted
   access-only OAuth bundle is present, then Kimi K3.
2. Cursor Grok 4.5 Medium when `CURSOR_API_KEY` is available.
3. Antigravity where the cadence permits it.
4. Gemini.

OpenCode runs through `scripts/workflows/lib/run-opencode.mjs` using SDK v2
sessions. The adapter validates model text against the cadence JSON Schema and
sends one explicit corrective prompt when validation fails. The OpenCode order
is `openai/gpt-5.6-sol`, when preflight permits it, then
`openrouter/moonshotai/kimi-k3@preset/consensus`. Provider failure advances to
Cursor `cursor-grok-4.5-medium`, then retained rollback providers when configured.
Fix calls use provider-specific isolation inside a shared disposable worktree;
the controller runs a credential-free baseline at clean `HEAD`, registers new
candidate paths, then runs `./test.sh` against the candidate. Provider invocation,
optional Gemini application, candidate verification, fix verification, and
outcome evidence are explicit fail-closed stages; a failed stage prevents later
stages from running and advances to the next provider. A malformed Gemini fix
response receives one corrective retry containing a bounded parse diagnostic and
the required schema. The controller promotes only the first patch with complete
per-finding verification. Missing, malformed, or pending verification therefore
cannot generate a committable stub.

Providers receive `repro_steps` as context but never as executable shell input.
They supply implementation reasoning, a proposed allowlisted harness identifier,
and a disposition. The controller reconstructs every finding identity from its
canonical batch, overwrites execution fields with baseline/candidate exit codes,
and generates outcome evidence. Rejected attempts produce one bounded redacted
diagnostic containing provider/model, failed stage/status, changed paths, diff
statistics, failing check names, and a capped excerpt. Daily and weekly fix jobs
upload those records with `always()`; raw responses and full patches are omitted.
The fix agent may edit but cannot invoke shell commands; this
prevents editable repository scripts from reading inherited credentials.

For trusted private repositories, `scripts/sync-opencode-oauth-secret.sh` reads
the local OpenCode OpenAI entry and updates the `OPENCODE_OPENAI_AUTH` Actions
secret only with `access`, `expires`, and `accountId`; `refresh` is replaced by
the inert `ci-refresh-disabled` placeholder. Invocation steps map it to
`OPENCODE_AUTH_CONTENT`. Codespace startup attempts this sync after PAT setup
only when repository visibility is verified as private; an unknown or public
target is skipped. Failure is non-fatal and leaves hosted provider fallback
available. Preflight requires 35 minutes for advisory, 105 minutes for daily,
135 minutes for weekly review, and 75 minutes for weekly fix. Missing, malformed,
stale, or refresh-enabled content is removed from the child environment and Sol
is omitted. The real refresh token never enters Actions, and hosted jobs never
refresh or write back OAuth state.

Workflows use GitHub-managed `ubuntu-latest`, configure Node 22, and run `npm ci`
against `.github/agent-runtime/package-lock.json`. Review and fix profiles live
beside that lockfile and are intentionally separate from interactive
`.opencode/opencode.json`. The adapter configures Undici's response-header and
body timeouts from `OPENCODE_TIMEOUT_MS` (default `900000`) so Node's five-minute
HTTP default cannot terminate a still-running `session.prompt()` before the
adapter's outer abort.

OpenCode LSP remains explicitly disabled in interactive and automated profiles.
The repository uses deterministic lint, schema, format, and test commands instead;
language servers may auto-download, consume additional memory/disk, drift by
version, and add latency. Enabling one requires a separate measured experiment
with a pinned command and automatic downloads disabled. See the
[OpenCode LSP guidance](https://opencode.ai/docs/lsp/).

The adapter does not use OpenCode 1.18.0's `format` field. That release ignores
`retryCount` and can finish without invoking its synthetic structured-output
tool. Adapter-owned validation also rejects model-authored `severity` and
`priority_band` values before retrying; cadence-specific validators remain the
final deterministic gate.

GitHub's hosted MCP endpoint is read-only and locked down through request headers.
Pre-merge Claude, OpenCode, and Cursor receive only the dedicated read-only token,
while deterministic shell code
retains all GitHub writes. The agent subprocess explicitly drops publisher and
sandbox credentials. The deterministic collector uses the workflow-scoped
`GITHUB_TOKEN` with `checks: read` to write check-run metadata into the local
evidence inventory; the agent PAT does not need Checks permission or shell access.

Review agents may fetch and search the public web to verify current documentation
and upstream behavior. OpenCode review profiles allow `webfetch` and `websearch`;
review workflows set `OPENCODE_ENABLE_EXA=1` so models routed through OpenAI or
OpenRouter can use Exa AI's unauthenticated hosted search service. That setting
applies to OpenCode candidates only; Claude's separate `WebFetch` and `WebSearch`
tools are unaffected. Claude pre-merge review allows exactly `Read`, `Glob`,
`Grep`, `WebFetch`, `WebSearch`, and the locked-down `github_read` MCP tools.
Cursor runs in plan mode with inline configuration for that same MCP. Bash,
edits, subagents, and
external-directory access remain denied, and provider isolation removes GitHub
publisher credentials before model execution. OpenCode fix profiles remain
offline, and this change grants no web access to other fix providers. External
pages are source material, not instructions; externally supported findings cite
URLs and must not transmit repository content in requests.

Large post-merge reviews use retrieval-first evidence. The deterministic
collector supplies repository/PR identity, merge and head SHAs, required source
paths, byte counts, and coverage metadata; it does not preload full startup
files or a capped diff into a tool-capable agent's prompt. Evidence lives under
ignored `.artifacts/` so the read-only OpenCode profile can inspect it without
external-directory permission. The review profile allows 24 agent steps for
repository and GitHub reads. Full-evidence OpenCode runs persist a sanitized
retrieval trace and fail provider validation unless observed reads cover the
complete diff, local evidence inventory, non-auto-loaded startup context, and
touched HEAD paths. OpenCode's system loader supplies the root `AGENTS.md`, so a
redundant tool read is not required for that file.

Daily and weekly `auto` analysis attempts available providers in OpenCode,
Cursor, then Gemini order, with cadence-specific Antigravity retained where enabled. A
provider transport, empty-result, or validation failure advances
to the next available provider. A large review is not reported as successful
after silently degrading to bounded evidence. Daily sequential runs record
failed PRs and continue finalization so successful retros and coverage artifacts
remain available.

## Multi-Model Consensus

The OpenCode `multi-model-consensus` skill is the sole opt-in multi-model path. Use it
only when requested or when consequential uncertainty justifies independent
perspectives. It does not replace the implementing agent or CI.

## Problem Framing And Critical Review

Problem framing and critical review are reasoning behaviors of the monolithic
implementing agent, not pipeline roles or blocking AI stages. The agent applies
the risk-based trigger in `AGENTS.md`; deeper product or market analysis uses
`docs/guides/problem-framing.md` only when it could materially change scope or
the user outcome. CI and lint remain the blocking pre-merge controls.

## Cross-PR Safety

`agent-parallelism-report.yml` reports exact path overlap between independent PRs.
Branch owners remain responsible for updating their branches and resolving
overlap; the template does not force-push automated rebases.

## Workflow verifiability classes

`scripts/verify-pr.sh` is the canonical classifier and owns the trigger rules.
Its fixtures in `scripts/tests/verify-pr.bats` define supported YAML shapes.

| Detected class | Verification |
|---|---|
| Code or documentation only | PR branch tests |
| Workflow includes `pull_request` and no default-only trigger | PR branch plus event run |
| Every other workflow, including dispatch-only | Sandbox default branch and relevant trigger event |
| Mixed paths | PR branch plus the most restrictive workflow target |

Use `docs/guides/outcome-validation.md` to select all environments and evidence
required by the user outcome. Use `docs/guides/sandbox-verification.md` when the
classifier reports `default-branch-only workflow` or a mixed diff with that
verification floor.

The read-only candidate harness reruns when relevant PR code changes and when
the PR body is edited, so live verification declarations cannot rely on an
earlier green result after they change.

## Labels

| Label | Meaning |
|---|---|
| `ai-review:live` | Enable rolling non-blocking advisory snapshots |
| `ai-review:full` | Force a full base-to-head advisory refresh |
| `auto-merge` | Opt in to auto-merge after required checks |
| `agent:claimed` | Work is actively claimed |
| `agent:blocked` | Work is blocked |
| `agent:awaiting-review` | Work awaits review |
| `agent-suggested` | Retro/advisory improvement candidate |

## Repository Variables

- `ADVISORY_REVIEW_PROVIDER` controls optional advisory provider selection.
- `POSTMERGE_RETRO_PROVIDER` and `WEEKLY_REVIEW_PROVIDER` control retro providers.
- Provider model and context variables are documented inline in their workflows.
## Required Secrets

- `OPENCODE_GITHUB_TOKEN`: fine-grained token with read-only Metadata, Contents,
  Pull requests, Issues, and Actions access to the target repository. Pre-merge
  Claude, OpenCode, and Cursor candidates all use it through the locked-down
  hosted MCP; none receives the workflow publisher token.
- `SKILL_REFRESH_PR_TOKEN`: fine-grained token restricted to the target
  repository with `Contents: read` and `Pull requests: write`. The skill-refresh
  finalizer uses it only to mark an exact-head validated draft ready; without
  `Contents: write`, it cannot merge.
- `OPENROUTER_API_KEY`: model credential for the hosted OpenCode Kimi fallback.
- `CLAUDE_OAUTH_SECRET`: one-year Claude subscription OAuth token generated by
  `claude setup-token` and stored manually with `gh secret set` or repository
  settings. The pre-merge workflow maps it to `CLAUDE_CODE_OAUTH_TOKEN`; daily
  and weekly workflows do not consume it.
- `OPENCODE_OPENAI_AUTH`: optional access-only ChatGPT OAuth JSON for Sol in a
  trusted private repository. Generate it with
  `scripts/sync-opencode-oauth-secret.sh`; never upload the real refresh token.
- Existing `CURSOR_API_KEY`, `GEMINI_API_KEY`, and `GOOGLE_API_KEY` remain
  optional rollback-provider credentials.
- Workflow publication uses the automatic job-scoped `GITHUB_TOKEN` with
  explicit least-privilege permissions. The readiness mutation is the bounded
  exception above. `SANDBOX_BOOTSTRAP_TOKEN` remains a sandbox-only credential
  and is never forwarded to OpenCode.

Use [`opencode-termination-diagnostics.md`](./opencode-termination-diagnostics.md)
when an interactive OpenCode process restarts unexpectedly.

## Retired Surfaces

ADR-031 retired role registries and overlays, formal Claude/Gemini review,
review-on-push, review resolution, final feedback consolidation, pre-push role
review, multi-role dispatch, and legacy consensus planning. Historical ADRs and
benchmark artifacts remain evidence, not operational instructions.
