# Multi-Model Consensus Planning

> **Optional, opt-in planning workflow.** Three independent candidate
> plans + one synthesized final plan for high-risk or architectural
> issues, before Judge plan-gate. The prompt that drives this workflow
> is [`.github/prompts/multi-model-consensus-plan.md`](../../.github/prompts/multi-model-consensus-plan.md).
> The decision to ship this as a prompt + guide rather than a new role
> is recorded in
> [ADR-024](../decisions/adr-024-multi-model-consensus-planning.md).

## What this is

A structured way to ask **multiple models** for independent plans on
the same issue, then merge them into one Judge-gated final plan.
Different models surface different tradeoffs, risks, simplifications,
and blind spots; comparing them in a fixed format makes those
differences legible and turns them into a single durable plan instead
of a scattered group chat.

This is **multi-model consensus planning**, not "multimodal consensus."
The workflow compares text-based plans from different models or
platforms; it does not combine text/image/audio modalities.

## What this is not

- **Not approval.** The final consensus plan is still a plan. Judge
  plan-gate runs on it just like any other plan-as-comment per
  [`.context/rules/process_gates.md`](../../.context/rules/process_gates.md).
- **Not the default planning path.** The default for almost every
  issue is one plan-as-comment using
  [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md).
- **Not a new role.** v1 deliberately keeps the canonical role set at
  10 (per ["the same 10 roles"](./multi-agent-coordination.md#the-roles),
  and the [dispatch reality matrix](./multi-agent-coordination.md#dispatch-reality-matrix)).
  The initiating agent (typically Architect) does the synthesis.
  Promotion of synthesis to a first-class `synthesizer` role is
  tracked in issue #296 and gated on five-plus high-stakes uses
  producing real evidence about misuse and failure modes.
- **Not a model-routing policy.** Tier expectations come from
  [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) and
  [ADR-019](../decisions/adr-019-per-role-model-tiering.md). This
  workflow does not introduce new tier rules; it inherits them.

## When to use

Run this workflow when one or more is true:

- The issue is architectural or ADR-worthy.
- The issue changes agent orchestration, workflow behavior, role
  definitions, or planning gates.
- The issue is ambiguous enough that multiple reasonable designs exist.
- The issue is high-risk, hard to roll back, or likely to create
  process or cost debt.
- A maintainer explicitly asks for consensus planning.

## When not to use

- Trivial docs edits, typo fixes, single-line bug fixes.
- Dependency bumps, mechanical refactors, lint fixups.
- Issues with one obvious correct implementation.
- Issues where the cost of three model passes plus a synthesis pass
  is not justified by the risk being mitigated.

If you are reaching for consensus planning more than ~once per
five-to-ten issues, you are probably over-using it. The default plan
path is fine for the long tail.

## Cost guardrails

- **Cap at three candidates.** More candidates rarely improve the
  signal and definitely raise cost.
- **One synthesis pass.** No nested re-syntheses. If the synthesis
  reveals the candidates were too far apart to merge, that is a signal
  to revise the issue or escalate to Architect, not to dispatch
  another round.
- **Reuse `.github/PLAN_TEMPLATE.md` model-tier rules.** Do not
  introduce a parallel routing policy for consensus runs.
- **Tie lineage back to the cost epic.** This workflow lives downstream
  of [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220)
  and ADR-019. If repeated use is moving costs the wrong way, that
  evidence belongs in the #220 thread.

## Workflow overview

```
Issue created
  ↓
Maintainer or Architect requests consensus planning
  ↓
Initiating agent gathers issue context once
  ↓
Three independent candidate plans produced from the same context
  ↓
Initiating agent synthesizes candidates (v1)
  ↓
Final consensus plan posted to the issue
  ↓
Judge plan-gates the final plan
  ↓
PM dispatches implementation if approved
```

## Candidate orchestration

```
Initiating agent
  ├─ Candidate planner A: model/platform 1, same context
  ├─ Candidate planner B: model/platform 2, same context
  └─ Candidate planner C: model/platform 3, same context
        ↓
Initiating agent synthesizes candidates
        ↓
Final consensus plan comment
        ↓
Judge plan-gate
```

Candidate planners must:

- Use the same issue body, acceptance criteria, repo context list, and
  known constraints from the initiating agent's Context Brief.
- Identify their model and platform in the candidate plan.
- Not read other candidates' outputs before posting their own.

The synthesizer must:

- Weight evidence quality over fluency.
- Favor a less polished but better-grounded candidate when warranted,
  and explain why.
- Drop or escalate unusable candidates per the prompt's failure-handling
  rules — never silently treat garbage output as valid input.

## Runtime fallback (subagents vs separate sessions)

Per [ADR-009 Decision 3 / the dispatch reality matrix](../decisions/adr-009-parallel-multi-agent-execution.md),
in-session role fan-out is currently fully wired only on Claude Code
CLI. This workflow is intended to compare multiple model/platform
perspectives — including ones Claude Code can't reach — so the prompt
is **prompt-first**, not subagent-only.

| Runtime | Recommended candidate dispatch |
|---|---|
| Claude Code CLI | Separate sessions per candidate (`Task(subagent_type: 'architect', ...)` ×3 in one CLI session would all use the same `model:` pinned in `.claude/agents/architect.md` and is **not** multi-model). For true multi-model fan-out from Claude Code, run each candidate as its own session against the desired model. |
| Copilot Chat (VS Code) | In-session subagents via `runSubagent(agentName: 'consensus-candidate-<vendor>', ...)` using the model-pinned overlays under `.github/agents/consensus-candidate-*.agent.md`. Note: ADR-009 lists the Copilot fan-out path as unverified end-to-end — fall back to separate chat sessions if the in-session path stalls. ADR-019 Amendment #6 ceiling still applies. |
| Cursor / Gemini / Web UIs | Separate sessions; the maintainer pastes the Context Brief and the candidate posts its result back as an issue comment. |
| Manual | Maintainer copies the Context Brief into N model UIs and posts the candidates by hand. |

The prompt **prefers** subagents when available, but never **requires**
them. The same Context Brief and same Candidate plan format make any
of these paths produce comparable artifacts.

## Bias guardrails

The synthesizer must weight **evidence quality over fluency**. It
must not pick the candidate that sounds most confident, polished, or
rhetorically smooth by default. Specifically, prefer:

- The plan whose file touch list maps best to the actual repo
  structure (no hallucinated paths).
- The plan whose acceptance-criteria mapping is the most direct.
- The plan whose verification block names commands that exist and
  exit codes that are testable.
- The plan whose risk handling names concrete mitigations rather than
  generic platitudes.

When a less fluent candidate is better grounded, the final plan must
say so and explain why it won.

## Candidate failure handling

A candidate is **unusable** if it fails to produce output, hallucinates
non-existent repo paths, omits required sections of the Candidate plan
format, drifts from the Context Brief, or is too generic to engage
with the issue at all.

The synthesizer either drops the candidate (with a one-sentence
reason in `Rejected / unusable candidates`) or stops and requests a
re-run when fewer than two usable candidates remain or when the
missing candidate represented a required perspective. Garbage in
must not pass through silently.

## Worked example (sketch)

Suppose issue #NNN proposes a change to how PM dispatches into
GitHub live-state comments and labels when two roles share a path glob. This is
ADR-worthy and has multiple plausible designs.

1. Initiating Architect reads issue #NNN, the relevant ADRs (009, 018),
  `agent_ownership.md`, and the latest `agent-state:v1` comment/labels.
  Posts a Context Brief in a comment.
2. Architect dispatches three candidate planners:
   - Subagent A: Architect role on Opus.
   - Subagent B: Architect role on Sonnet.
   - Separate session C: Architect on a non-Anthropic model via Copilot.
3. Each posts its candidate comment marked
   `<!-- consensus-plan-candidate -->`. C produces only half the
   required sections — Architect drops it under
   `Rejected / unusable candidates` with the reason "incomplete
   acceptance-criteria mapping; only 2 of 6 criteria covered."
4. Architect synthesizes A + B into one final plan marked
   `<!-- consensus-plan-final -->`. B's verification block was more
   grounded; A's risk table was sharper. The final plan adopts B's
   verification and A's risks, says so explicitly under "Why this
   approach won," and lists C in `Rejected / unusable candidates`.
5. Architect's last action names **Judge plan-gate** as the next
   handoff. Not PM dispatch.
6. Judge runs plan-gate per the normal procedure. If `APPROVE`, PM
   dispatches.

## Manual sandbox verification

Before merging changes that materially alter this workflow, run a
live verification in the sandbox repo:

1. Create or reuse a scratch issue.
2. Run [`.github/prompts/multi-model-consensus-plan.md`](../../.github/prompts/multi-model-consensus-plan.md)
   against that issue.
3. Use subagents for candidate planning if the runtime supports them;
   otherwise use separate candidate sessions/comments.
4. Produce three candidate comments using
   `<!-- consensus-plan-candidate -->`.
5. Produce one final consensus comment using
   `<!-- consensus-plan-final -->`.
6. Confirm all four comments render correctly, preserve nested code
   fences, include required sections, and that at least one
   intentionally weak candidate is handled per the failure-handling
   rules.
7. Confirm the final consensus plan names **Judge plan-gate** as the
   next handoff, not PM dispatch.

## Diagnosing future hangs

If a consensus run hangs the editor session (parent stops responding
mid-dispatch or mid-synthesis), start
[`scripts/diag-hang-snapshot.sh`](../../scripts/diag-hang-snapshot.sh)
in a background shell **before** re-triggering the run. It captures a
rolling snapshot of `top`, `ps`, `ss -tnp`, `free -h`, and the
`$VSCODE_TARGET_SESSION_LOG` tail every few seconds into
`/tmp/hang-diag-${USER}/run-<timestamp>-<pid>/` (the script's default
`OUTDIR` is `/tmp/hang-diag-${USER}`; override with `OUTDIR=...` if you
prefer a different location). After the next hang, grep
`samples.log` for ESTABLISHED TCP connections to `*.githubcopilot.com`
or `*.github.com` (a network stall inside a subagent boundary) and
for `extensionHost` RSS growth approaching the host's memory ceiling
(parent-context bloat from large inline tool returns). The PR #297
dry-run #3 finding was that `fetch` and `githubRepo` tool grants on
the candidate overlays were the most likely root cause of earlier
stalls; if those grants are reintroduced on any subagent overlay,
that is the suspect-first hypothesis.

## See also

- [`.github/prompts/multi-model-consensus-plan.md`](../../.github/prompts/multi-model-consensus-plan.md) — the prompt itself.
- [`docs/decisions/adr-024-multi-model-consensus-planning.md`](../decisions/adr-024-multi-model-consensus-planning.md) — prompt-first / no-new-role decision.
- [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md) §`P9` — pattern entry.
- [docs/guides/multi-agent-coordination.md](multi-agent-coordination.md) — where consensus planning fits in the pipeline.
- [`docs/decisions/adr-019-per-role-model-tiering.md`](../decisions/adr-019-per-role-model-tiering.md) — model-tier rules this workflow inherits.
- [`docs/decisions/adr-009-parallel-multi-agent-execution.md`](../decisions/adr-009-parallel-multi-agent-execution.md) Decision 3 — dispatch reality matrix that motivates the runtime fallback.
- Parent epic [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220) — AI cost-mitigation strategy lineage.
- Follow-up [#296](https://github.com/mikejmckinney/ai-repo-template/issues/296) — possible synthesizer-role promotion.
