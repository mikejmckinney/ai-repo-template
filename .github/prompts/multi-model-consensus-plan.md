---
description: Run optional multi-model consensus planning — 3 candidate plans + 1 synthesized final plan before Judge plan-gate.
agent: agent
---

# Multi-Model Consensus Planning

> **Optional, opt-in workflow.** Run only on high-risk, architectural,
> ambiguous, or ADR-worthy issues — not on trivial docs edits, typo fixes,
> dependency bumps, small bug fixes, or mechanical refactors. See
> [`docs/guides/multi-model-consensus.md`](../../docs/guides/multi-model-consensus.md)
> for trigger criteria, cost guardrails, and worked examples.
>
> **This is a procedural prompt, not a deliverable prompt.** It does not
> require Analyst pre-flight (per `.github/prompts/README.md` §"Files
> here"). The implementation work it produces still flows through the
> normal pipeline (Analyst pre-flight where applicable → plan-as-comment
> → Judge plan-gate → PM dispatch → implementers → QA → Critic → Judge
> diff-gate).

## What this prompt does

Produces, for one issue:

1. Up to **three independent candidate plans** from different models or
   platforms, generated from identical issue context.
2. **One final consensus plan**, synthesized by the initiating agent,
   posted as the canonical plan-as-comment for that issue.

The final consensus plan is **not approval**. It must still go through
Judge plan-gate exactly like a single-author plan would (per
[`.context/rules/process_gates.md`](../../.context/rules/process_gates.md)
§"Plan-as-comment requirement").

## When to use

Run this workflow when one or more is true:

- The issue is architectural or ADR-worthy.
- The issue changes agent orchestration, workflow behavior, role
  definitions, or planning gates.
- The issue is ambiguous enough that multiple reasonable designs exist.
- The issue is high-risk, hard to roll back, or likely to create
  process/cost debt.
- A maintainer explicitly asks for consensus planning (e.g. by labeling
  the issue or commenting `@<agent> follow .github/prompts/multi-model-consensus-plan.md`).

## When not to use

- Trivial docs edits, typo fixes, single-line bug fixes.
- Dependency bumps, mechanical refactors, lint fixups.
- Issues with a single obvious correct implementation.
- Issues where the cost of three model passes plus a synthesis pass is
  not justified by the risk being mitigated.

The default planning path is one plan-as-comment per
[`.github/PLAN_TEMPLATE.md`](../PLAN_TEMPLATE.md). Reach for consensus
planning only when the extra cost is worth the better tradeoff
visibility.

## Inputs

- The target **issue number** (`#NN`).
- The **issue body**, **acceptance criteria**, and any prior comments
  that constrain the design (existing pre-flight reports, prior plan
  revisions, related ADRs).
- The repo context the issue depends on, gathered once by the initiating
  agent so all candidate planners see the same facts. At minimum:
  - [`AI_REPO_GUIDE.md`](../../AI_REPO_GUIDE.md)
  - [`.context/00_INDEX.md`](../../.context/00_INDEX.md)
  - [`.context/rules/agent_ownership.md`](../../.context/rules/agent_ownership.md)
  - The latest `agent-state:v1` issue/PR comment and labels for live coordination state
  - The relevant ADRs and rule files named in the issue.

## Roles in this workflow

- **Initiating agent** — gathers context, dispatches candidate planners,
  performs the synthesis pass in v1, and posts the final consensus
  comment. Typically Architect or Analyst.
- **Candidate planners A, B, C** — produce one candidate plan each from
  the same context. Subagents when the runtime supports them; otherwise
  separate model/chat sessions or manual candidate runs.
- **Judge** — plan-gates the final consensus comment using the normal
  plan-gate criteria.
- **PM** — dispatches implementation if Judge approves.

In v1 the initiating agent does the synthesis. A dedicated
`synthesizer` role is **not** added in v1; promotion is tracked in
issue #296 and only justified once five-plus high-stakes uses prove
the workflow is durable.

## Procedure

### Step 1 — Gather issue context once

The initiating agent reads the issue body, acceptance criteria, and the
context files above. It produces a single **Context Brief** that all
candidate planners will see. The brief should fit in one comment / one
prompt and include:

- Issue number, title, link.
- Verbatim acceptance criteria (do not paraphrase — drift here breeds
  fake disagreement between candidates).
- Inline outcome paragraph from the issue (the 15-minute test).
- The repo context list above.
- Known constraints (referenced ADRs, ownership boundaries, model-tier
  ceilings, related epics).
- Requested output format (the **Candidate plan format** below).

### Step 2 — Dispatch candidate planners

Generate up to **three** independent candidate plans. Two is the
minimum useful number; one is just a regular plan and should be done
through `.github/PLAN_TEMPLATE.md` instead.

**Runtime selection (in order of preference):**

1. **In-session subagents with model-pinned candidate overlays.** If
   the runtime supports them (Claude Code CLI today; VS Code Copilot
  Chat with the `runSubagent` tool — see ADR-009 Decision 3 and the
  dispatch reality matrix in
  [docs/guides/multi-agent-coordination.md](../../docs/guides/multi-agent-coordination.md)),
   the initiating agent dispatches the candidate planners as
   subagents. This isolates each candidate's reasoning context from
   the others.

   **Caveat (uncertain):** ADR-009 still labels the Copilot Chat
   `runSubagent` fan-out path as **unverified end-to-end**; the
   matrix lists Claude Code CLI as the only fully wired in-session
   path today. The Copilot path below describes how to dispatch
   when it does work, but operators should treat path 2
   (separate sessions) as the dependable fallback and not assume
   Copilot in-session fan-out will succeed in their environment
   without trying it first.

   **On Claude Code specifically**, the standard role overlays in
   `.claude/agents/<role>.md` carry fixed `model:` pins; calling
   `Task(subagent_type: 'architect', ...)` three times yields three
   sessions on the **same** model and does not satisfy the
   multi-model intent of this workflow. There are intentionally **no**
   `consensus-candidate-*` overlays under `.claude/agents/`
   (per `scripts/checks/050-agent-mirror.sh` exemptions): Claude Code
   today does not support per-subagent model overrides for arbitrary
   model vendors. On Claude Code, prefer path 2 below (separate
   sessions per candidate model).

   **On Copilot Chat specifically**, the `runSubagent` tool does
   **not** accept a `model` parameter, and Copilot's subagent loader
   does not honor natural-language model hints in subagent prompt
   bodies; the only reliable way to pin a candidate's model is via
   the overlay's `model:` frontmatter field (see ADR-019). Three
   Copilot-only candidate overlays exist for exactly this purpose:

   | Candidate | Overlay | Model pin |
   |---|---|---|
   | A | [`.github/agents/consensus-candidate-claude.agent.md`](../agents/consensus-candidate-claude.agent.md) | `Claude Opus 4.7 (copilot)` |
   | B | [`.github/agents/consensus-candidate-gpt.agent.md`](../agents/consensus-candidate-gpt.agent.md) | `GPT-5.5 (copilot)` |
   | C | [`.github/agents/consensus-candidate-gemini.agent.md`](../agents/consensus-candidate-gemini.agent.md) | `Gemini 3.1 Pro (Preview) (copilot)` |

   Dispatch each via `runSubagent(agentName: 'consensus-candidate-<vendor>', ...)`.
   Natural-language model hints in the subagent prompt body do **not**
   override the parent session's model and must not be relied on.

   **Dispatch all candidates in a single parallel tool batch**, not
   sequentially across multiple parent turns. Empirical finding from
   PR #297 dry-run #3 (2026-05-11): the candidate overlays' previous
   network-tool grants (`fetch`, `githubRepo`) appear to have been
   the primary cause of observed parent-session stalls during
   sequential dispatch — likely a blocking I/O wait inside the
   subagent boundary that the parent could not interrupt. Those
   grants have been removed from `consensus-candidate-*` overlays
   (the candidates now have only `read`, `search`, `usages`) and
   rely entirely on the pre-baked Context Brief from Step 1.
   Parallel dispatch is now safe and is preferred because it
   completes the fan-out in one parent turn instead of three.
2. **Separate model/chat sessions.** When in-session subagents are not
   available (Cursor, Gemini today), the initiating agent
   either:
   - Asks the maintainer to open the same issue in a different
     model/session and run the prompt there, or
   - Runs the candidate planning passes itself in distinct sessions
     against different model pins, posting each candidate as its own
     issue comment.
3. **Manual candidate runs.** A maintainer may paste the Context Brief
   into a different model's web UI and post the result back as a
   candidate comment. This is the lowest-tech fallback.

The prompt **prefers** subagents where available. The prompt **does
not require** subagents — the workflow must remain executable on
runtimes that lack in-session role fan-out.

**Isolation requirement:** candidate planners must not read each
other's outputs before producing their own candidate plan. Cross-reads
collapse the diversity that motivates the workflow. Order of posting
does not matter; cross-influence does.

**Same context requirement:** every candidate planner receives the
same issue body, acceptance criteria, repo context list, and known
constraints from the Context Brief. Any candidate that strays from
this context (e.g., invents a different acceptance criterion) is a
candidate-failure case (see Step 4).

### Step 3 — Each candidate posts its candidate plan

Each candidate plan goes in as a separate issue comment using the
**Candidate plan format** below, marked with the literal HTML comment
`<!-- consensus-plan-candidate -->` so the synthesizer can find them
and the final consensus comment can permalink them. Each candidate
identifies its model and platform.

**Posting responsibility:**

- **In-session subagent path** — the subagent returns its candidate
  plan text to the initiating agent. The **initiating agent** is
  responsible for posting that text to the issue as a separate
  comment (one comment per candidate), preserving the
  `<!-- consensus-plan-candidate -->` marker and the candidate's
  declared model/platform line. Subagents in this repo do not have
  comment-write tools by default (uncertain — verified by inspection
  of the `tools:` arrays in `.github/agents/*.agent.md` overlays at
  PR #297 time, e.g. `architect.agent.md` lists
  `['read', 'write', 'search', 'fetch', 'githubRepo', 'usages', 'todo']`
  with no `gh`/comment tool); the initiating agent is the
  posting authority.
- **Separate-session path** — whoever ran the candidate session
  (the maintainer, or the same agent in a different session) posts
  the candidate plan as a comment directly. The initiating agent
  collects the resulting permalinks for the synthesis pass.
- **Manual path** — the maintainer pastes the candidate output into
  an issue comment by hand.

In every path, the result is the same: one issue comment per
candidate, marked with `<!-- consensus-plan-candidate -->`, with a
permalink the synthesizer can cite under `Candidates reviewed` in
the final plan.

#### Subagent return is inline (currently)

A prior version of this prompt instructed candidate planners to write
their full plan to `/tmp/consensus/<issue>-candidate-<id>.md` and
return only a three-line `WROTE:/MODEL:/SUMMARY:` handle, to keep the
parent context small. **That convention is currently inert** in the
Copilot SDK runtime: the overlays' `write` tool grant does not
actually expose `create_file` (or any disk-write primitive) at the
subagent boundary as of PR #297 dry-run #3 (2026-05-11). Worse, one
candidate (Gemini) hallucinated a `WROTE: ...` success line in
response to those instructions even though no file was written —
honest inline return is strictly safer than a fabricated handle.

Until the actual tool-grant string for subagent disk-write is
identified (tracked separately as a follow-up to PR #297), candidate
planners **return their full plan inline** as their sole reply text,
and the initiating agent posts that text directly per the
**Posting responsibility** rules above. Keep candidate plans focused
(~5–8 KB target) so the parent context stays manageable.

### Step 4 — Synthesize

The initiating agent reads all candidate-plan comments and produces a
single **Final consensus plan** comment using the **Final consensus
plan format** below, marked with `<!-- consensus-plan-final -->`.

#### Bias guardrails (REQUIRED)

The synthesizer must weight **evidence quality over fluency**. It must
not pick the candidate that sounds most confident, polished, or
rhetorically smooth by default. Explicitly favor:

- The plan whose file touch list maps best to the actual repo
  structure (no hallucinated paths, no invented files).
- The plan whose acceptance-criteria mapping is the most direct
  (one cell per criterion, no hand-waving).
- The plan whose verification block names commands that exist and
  exit codes that are testable.
- The plan whose risk handling names concrete mitigations rather than
  generic platitudes ("we will be careful," "we will test thoroughly").

When a less fluent candidate is better grounded than a more polished
one, **the final consensus plan must say so and explain why it won.**
Record the choice under "Why this approach won" so reviewers can audit
the call.

#### Candidate failure handling (REQUIRED)

A candidate plan is **unusable** if it:

- Failed to produce output (timeout, refusal, rate limit).
- Hallucinates non-existent repo paths, files, ADRs, or scripts.
- Omits required sections of the Candidate plan format.
- Drifts from the Context Brief (different acceptance criteria, wrong
  issue, wrong scope).
- Is so generic it does not engage with the issue at all.

When one or more candidates is unusable, the synthesizer must either:

1. **Drop the candidate** and record it under
   `Rejected / unusable candidates` in the final plan with a
   one-sentence reason; or
2. **Stop and request a re-run** when fewer than two usable candidate
   plans remain, or when the missing candidate represented a required
   perspective (e.g., the only candidate that examined the
   security/cost/cross-platform angle was the one that failed).

The synthesizer **must not** silently treat garbage output as valid
consensus input. Every candidate must appear in either
`Candidates reviewed` or `Rejected / unusable candidates`; nothing
disappears without a noted reason.

### Step 5 — Hand off to Judge

The initiating agent's last action is a comment or PR-thread reply that
explicitly names the next handoff: **Judge plan-gate**. Not PM
dispatch. The final consensus plan is a plan, not an approval.

If Judge returns `APPROVE`, PM dispatches per the normal pipeline. If
Judge returns `REQUEST_CHANGES` or `BLOCK`, the initiating agent
revises (a "Plan revision" comment per
[`.context/rules/process_gates.md`](../../.context/rules/process_gates.md))
or, if the disagreement was structural, considers re-running consensus
planning. Re-running is rarely worth the cost — usually a targeted
revision on the existing final plan is enough.

## Model tier expectations

This workflow inherits model-tier expectations from
[`.github/PLAN_TEMPLATE.md`](../PLAN_TEMPLATE.md) and ADR-019. It does
**not** define a separate model-routing policy. In particular:

- Candidate planners can — and usually should — use **different**
  models or platforms. That diversity is the point.
- The initiating agent's model tier and the synthesis pass tier follow
  the planning-role tier from ADR-019 (currently `top` for
  Architect-led work; ADR-019 Amendment #6 still applies on Copilot).
- Document the model used for each candidate in that candidate's
  comment so the final plan's `Candidates reviewed` list can cite it.

## Candidate plan format

Each candidate plan must use this exact structure so the synthesizer
can compare candidates directly. The outer fence intentionally uses
four backticks so the embedded ` ```bash ` fence renders inside the
example instead of ending the block early.

````markdown
<!-- consensus-plan-candidate -->

# Consensus Candidate Plan

**Issue:** #<number>
**Model / platform:** <model and runtime, e.g. "Claude Opus 4.7 on Claude Code">
**Role:** Architect or Analyst
**Date:** YYYY-MM-DD

## Context Sources Reviewed

- `AI_REPO_GUIDE.md`
- `.context/00_INDEX.md`
- `.context/rules/agent_ownership.md`
- Latest `agent-state:v1` issue/PR comment and labels
- Relevant issue body and comments

## Problem Understanding

<What this candidate believes the issue is trying to accomplish, in DO-language.>

## Recommended Approach

<Plan summary.>

## File Touch List

- `path/to/file` — <reason>

## Acceptance Criteria Mapping

| Acceptance criterion | Plan step that satisfies it |
|---|---|
| <criterion> | <plan step> |

## Risks / Tradeoffs

| Risk | Mitigation |
|---|---|
| <risk> | <mitigation> |

## Alternatives Considered

| Alternative | Why not chosen |
|---|---|
| <alternative> | <reason> |

## Verification Plan

```bash
<commands>
```

## Confidence

**Confidence:** High / Medium / Low

## Open Questions

- <question, or `None`>
````

## Final consensus plan format

The synthesizer must not simply average the candidates. It must
preserve provenance and explain why the final plan chose some ideas
and rejected others. The outer fence intentionally uses four backticks
so the embedded ` ```bash ` fence renders inside the example.

````markdown
<!-- consensus-plan-final -->

# Multi-Model Consensus Final Plan

**Issue:** #<number>
**Synthesized by:** <model and runtime>
**Date:** YYYY-MM-DD
**Candidates reviewed:**
- <candidate A permalink — model/platform>
- <candidate B permalink — model/platform>
- <candidate C permalink — model/platform>

## Areas of Agreement

- <point all usable candidates agreed on>

## Areas of Disagreement

<!-- Column count must match the number of usable candidates. The
     example below uses three because that is the typical case (per
     Step 2 “typically 3, minimum 2”). For a two-candidate run, drop
     the `Candidate C` column entirely. Do not invent placeholder data
     for missing candidates — missing data weakens provenance. List
     every excluded candidate in the `Rejected / Unusable Candidates`
     section below with a one-sentence reason. -->

| Topic | Candidate A | Candidate B | Candidate C | Final decision |
|---|---|---|---|---|
| <topic> | <view> | <view> | <view> | <decision> |

## Selected Final Approach

<The merged approach, written as one coherent plan — not three plans stapled together.>

## Confidence

**Confidence:** High / Medium / Low

## Why This Approach Won

<Decision rationale. Cite evidence quality, repo grounding, acceptance-criteria mapping, and risk handling. If a less fluent candidate won, say so and explain why.>

## Rejected Ideas

| Idea | Source | Rejection reason |
|---|---|---|
| <idea> | <candidate> | <reason> |

## Rejected / Unusable Candidates

| Candidate | Reason it could not be used |
|---|---|
| <candidate / model> | <one-sentence reason; omit row if all candidates were usable> |

## Final File Touch List

- `path/to/file` — <reason>

## Implementation Phases

1. <phase>
2. <phase>

## Verification

```bash
<commands>
```

**Change class:** <code-or-docs | pull_request-triggered workflow | default-branch-only workflow | mixed>
**Verification target:** <PR branch | sandbox repo | both>

<!-- Use the canonical ADR-016 values from `.github/PLAN_TEMPLATE.md`.
     `scripts/verify-pr.sh` validates the declared class against the
     actual changed paths. Default-branch-only changes must be verified
     in the sandbox sibling repo before merging. -->

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| <risk> | <mitigation> |

## Model Tier

**Tier:** <inherits from `.github/PLAN_TEMPLATE.md` and ADR-019 — typically `top` for Architect-led consensus work>
**Justification (required when `top`):** <one sentence>

## Handoff

- **Next:** Judge plan-gate (NOT PM dispatch — the consensus plan is not approval).
- **Then, if approved:** PM dispatch per the normal pipeline.
````

## Verification (for the implementer of this prompt itself)

If you are reviewing or editing this prompt:

```bash
# Frontmatter present
head -1 .github/prompts/multi-model-consensus-plan.md | grep -q '^---$'

# README lists the prompt
grep -q multi-model-consensus-plan .github/prompts/README.md

# Test suite stays green
./test.sh
```

## See also

- [`docs/guides/multi-model-consensus.md`](../../docs/guides/multi-model-consensus.md) — when/when-not, cost guardrails, examples, runtime fallback walkthrough.
- [`docs/decisions/adr-024-multi-model-consensus-planning.md`](../../docs/decisions/adr-024-multi-model-consensus-planning.md) — why this is a prompt + guide rather than a new role.
- [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md) §`P9` — Multi-Model Plan Consensus pattern entry.
- [`docs/decisions/adr-009-parallel-multi-agent-execution.md`](../../docs/decisions/adr-009-parallel-multi-agent-execution.md) Decision 3 — dispatch reality matrix that motivates the runtime fallback.
- [`docs/decisions/adr-019-per-role-model-tiering.md`](../../docs/decisions/adr-019-per-role-model-tiering.md) — model tier rules this workflow inherits, including Amendment #6 (Copilot subagent cost-tier ceiling).
- [`.github/PLAN_TEMPLATE.md`](../PLAN_TEMPLATE.md) — the standard plan format the final consensus plan must remain compatible with.
- Parent epic [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220) — AI cost-mitigation strategy lineage.
- Follow-up [#296](https://github.com/mikejmckinney/ai-repo-template/issues/296) — possible promotion of synthesis to a first-class `synthesizer` role once usage evidence justifies it.
