# Agent Pipeline

ADR-031 defines a monolithic implementation and review lifecycle. One agent owns
routine implementation; CI blocks regressions; advisory review is optional and
parallel; daily and weekly review operate after changes reach `main`.

## Implementation

Use one implementing agent on a non-default branch. Keep issue/PR live-state
comments only when work is paused, blocked, awaiting review, or handed off.

Issue assignment is operator-driven. The template does not provision a coding-agent
queue or automatically transition draft PRs.

## Advisory Review

`agent-advisory-review.yml` is explicitly opt-in through `ai-review:live`.
It runs for same-repository open PRs, including drafts, on qualifying open,
reopen, synchronize, ready, and label events. Concurrency is keyed by PR and
`cancel-in-progress: true`, so implementation never waits for an older snapshot.

The workflow posts or updates one `<!-- ai-advisory-review:v1 -->` comment. It
cannot submit formal reviews, push commits, mutate labels, resolve threads,
change readiness, or block merge. `ai-review:full` requests deeper context only.

## Blocking Pre-Merge Controls

Repository tests and lint/format checks are the blocking controls. Branch rulesets
must require their check names. Advisory, overlap reports, and retro outputs are
supporting evidence and never satisfy or replace deterministic CI.

## Daily Post-Merge Retro

`agent-postmerge-retro.yml` runs at 06:00 UTC and by manual dispatch. It reviews
merged PR evidence, writes one daily umbrella issue, and may publish a draft fix
PR. Fix publication is never auto-merged.

## Weekly Repository Review

`agent-weekly-review.yml` runs Sunday at 07:00 UTC and by manual dispatch. It
performs a static full-repository scan of `main`, writes one ISO-week umbrella,
and may publish a draft fix PR.

Daily and weekly adapters share provider routing, priority derivation,
supersession, umbrella transport, and batch-fix publication under
`scripts/workflows/lib/`. Their schemas, templates, markers, and evidence inputs
remain cadence-specific.

## OpenCode Runtime

Advisory, daily, and weekly automation resolve `auto` in this order:

1. OpenCode when the runtime, `OPENCODE_GITHUB_TOKEN`, and
   `OPENROUTER_API_KEY` are available.
2. Cursor.
3. Antigravity where the cadence permits it.
4. Gemini.

OpenCode runs through `scripts/workflows/lib/run-opencode.mjs` using SDK v2
sessions. The adapter validates model text against the cadence JSON Schema and
sends one explicit corrective prompt when validation fails, then tries
`openrouter/z-ai/glm-5.2@preset/default` and
`openrouter/minimax/minimax-m3@preset/default` in order. Subscription-backed
`openai/gpt-5.6-sol` remains available to interactive local OpenCode and
`local-consensus`, not public CI. Fix calls go through
`run-opencode-fix.sh`, which creates and discards one detached worktree per model
and applies only a schema-valid attempt whose credential-free controller-side
`./test.sh` run passes. The fix agent may edit but cannot invoke shell commands;
this prevents editable repository scripts from reading inherited credentials.

Workflows use GitHub-managed `ubuntu-latest`, configure Node 22, and run `npm ci`
against `.github/agent-runtime/package-lock.json`. Review and fix profiles live
beside that lockfile and are intentionally separate from interactive
`.opencode/opencode.json`. The adapter configures Undici's response-header and
body timeouts from `OPENCODE_TIMEOUT_MS` (default `900000`) so Node's five-minute
HTTP default cannot terminate a still-running `session.prompt()` before the
adapter's outer abort.

The adapter does not use OpenCode 1.18.0's `format` field. That release ignores
`retryCount` and can finish without invoking its synthetic structured-output
tool. Adapter-owned validation keeps retries observable and leaves the existing
cadence-specific validators as the final deterministic gate.

GitHub's hosted MCP endpoint is read-only and locked down through request headers.
Agents receive only the dedicated read-only token, while deterministic shell code
retains all GitHub writes. The agent subprocess explicitly drops publisher and
sandbox credentials.

Large post-merge reviews use retrieval-first evidence. The deterministic
collector supplies repository/PR identity, merge and head SHAs, required source
paths, byte counts, and coverage metadata; it does not preload full startup
files or a capped diff into a tool-capable agent's prompt. Evidence lives under
ignored `.artifacts/` so the read-only OpenCode profile can inspect it without
external-directory permission. The review profile allows 24 agent steps for
repository and GitHub reads. Full-evidence OpenCode runs persist a sanitized
retrieval trace and fail provider validation unless observed reads cover the
complete diff, local evidence inventory, startup context, and touched HEAD paths.

With `auto`, analysis attempts available providers in OpenCode, Cursor, then
Gemini order. A provider transport, empty-result, or validation failure advances
to the next available provider. A large review is not reported as successful
after silently degrading to bounded evidence. Daily sequential runs record
failed PRs and continue finalization so successful retros and coverage artifacts
remain available.

## Local Consensus

The OpenCode `local-consensus` skill is the sole opt-in multi-model path. Use it
only when requested or when consequential uncertainty justifies independent
perspectives. It does not replace the implementing agent or CI.

## Cross-PR Safety

`agent-parallelism-report.yml` reports exact path overlap between independent PRs.
Branch owners remain responsible for updating their branches and resolving
overlap; the template does not force-push automated rebases.

## Workflow verifiability matrix

| Trigger or surface | Verification |
|---|---|
| Code/docs only | PR branch tests |
| `pull_request` workflow | PR branch plus event run |
| `schedule`, `workflow_dispatch`, `push`, `workflow_run` | Sandbox default branch |
| `pull_request_target`, reviews, issue comments | Sandbox trigger event |
| Mixed changes | Both PR branch and sandbox |

Use `scripts/verify-pr.sh` to classify the diff and
`docs/guides/sandbox-verification.md` for default-branch-only exercise.

## Labels

| Label | Meaning |
|---|---|
| `ai-review:live` | Enable rolling non-blocking advisory snapshots |
| `ai-review:full` | Increase advisory context depth |
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
  Pull requests, Issues, and Actions access to the target repository.
- `OPENROUTER_API_KEY`: model credential for the ordered public-CI OpenCode cascade.
- Existing `CURSOR_API_KEY`, `GEMINI_API_KEY`, and `GOOGLE_API_KEY` remain
  optional rollback-provider credentials.
- `CLAUDE_PAT` and `SANDBOX_BOOTSTRAP_TOKEN` remain deterministic publication or
  sandbox credentials and are never forwarded to OpenCode.

Use [`opencode-termination-diagnostics.md`](./opencode-termination-diagnostics.md)
when an interactive OpenCode process restarts unexpectedly.

## Retired Surfaces

ADR-031 retired role registries and overlays, formal Claude/Gemini review,
review-on-push, review resolution, final feedback consolidation, pre-push role
review, multi-role dispatch, and legacy consensus planning. Historical ADRs and
benchmark artifacts remain evidence, not operational instructions.
