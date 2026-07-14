# Agent Pipeline

ADR-031 defines a monolithic implementation and review lifecycle. One agent owns
routine implementation; CI blocks regressions; advisory review is optional and
parallel; daily and weekly review operate after changes reach `main`.

## Implementation

Use one implementing agent on a non-default branch. Keep issue/PR live-state
comments only when work is paused, blocked, awaiting review, or handed off.

The retained assignment workflows (`agent-assign-copilot.yml`,
`agent-auto-ready.yml`, and `agent-release-slot.yml`) assign one agent to an issue;
they do not dispatch role pipelines.

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

## Local Consensus

The OpenCode `local-consensus` skill is the sole opt-in multi-model path. Use it
only when requested or when consequential uncertainty justifies independent
perspectives. It does not replace the implementing agent or CI.

## Cross-PR Safety

`agent-parallelism-report.yml` reports exact path overlap between independent PRs.
`auto-rebase-on-merge.yml` uses `scripts/lib/overlap.sh` to distinguish hard and
soft overlap for opted-in PRs. These are repository-concurrency safeguards, not
multi-agent orchestration.

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
| `auto-rebase` | Opt in to overlap-aware rebase after another PR merges |
| `do-not-rebase` | Disable automatic rebase |
| `agent:claimed` | Work is actively claimed |
| `agent:blocked` | Work is blocked |
| `agent:awaiting-review` | Work awaits review |
| `agent-suggested` | Retro/advisory improvement candidate |

## Repository Variables

- `ADVISORY_REVIEW_PROVIDER` controls optional advisory provider selection.
- `POSTMERGE_RETRO_PROVIDER` and `WEEKLY_REVIEW_PROVIDER` control retro providers.
- `MAX_COPILOT_CONCURRENT` and `MAX_COPILOT_DAILY` bound monolithic assignment.
- Provider model and context variables are documented inline in their workflows.

## Retired Surfaces

ADR-031 retired role registries and overlays, formal Claude/Gemini review,
review-on-push, review resolution, final feedback consolidation, pre-push role
review, multi-role dispatch, and legacy consensus planning. Historical ADRs and
benchmark artifacts remain evidence, not operational instructions.
