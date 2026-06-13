# Prompts Directory

Prompt files referenced from GitHub issues and PR comments. These are reusable procedures, not active task-state stores. Live coordination state belongs in the assigned issue/PR's latest `agent-state:v1` comment per ADR-025.

## Before writing a new project prompt

Project prompts (like `NN-<stage>.md`) are validated by the **Analyst role**
before any implementation starts. Analyst applies the "15-minute test" from
[`.agents/analyst.md`](../../.agents/analyst.md) →
"Pre-Flight Validation" (the gate also applies to ad-hoc deliverable
issues per ADR-014):

> If the intended audience spent 15 minutes with the final deliverable,
> would they *experience* the outcome, or would they *read about* it?

Prompts that list deliverables without specifying the user outcome fail
pre-flight. The most common failure: describing 6 React pages instead of
describing what a user will be able to *do* with those pages.

Lead your prompt with **Client-facing outcomes** (concrete user actions)
and **Non-negotiables** (things that must be real, not mocked). File
lists come after, not before.

## Files here

- **Shared procedural prompts** (template-provided; e.g.) — `pr-resolve-all.md`,
  `repo-onboarding.md`, `expand-backlog-entry.md`, `capture-postmortem.md`,
  `mirror-postmortem.md`, `pre-push-review.md`, `multi-model-consensus-plan.md`,
  `instruction-compliance-smoke.md`.
  These describe procedures, not deliverables, and don't require pre-flight.
  - **`pr-advisory-review.md`** — non-blocking four-lens advisory snapshot for
    draft/WIP PRs when `ai-review:live` is applied (`agent-advisory-review.yml`).
  - **`pr-final-feedback-consolidation.md`** — final Feedback Inbox consolidation
    when `implementation-complete` is applied (`agent-review-finalize.yml`).
  - **`post-merge-retro.md`** — per-PR post-merge retrospective JSON (used inside daily batch).
  - **`post-merge-retro-fix.md`** — daily fix pass for `retro/fix-YYYY-MM-DD` draft PRs.
    Pipeline design: [ADR-030](../../docs/decisions/adr-030-non-blocking-review-pipeline.md) (issue #426).
  - **`pre-push-review.md`** — Critic + lint + `./test.sh` summary against
    the working-tree diff before push. SHOULD per AGENTS.md →
    "Work style"; MUST for the DevOps role on shell/workflow changes
    (issue #229 Phase 3).
  - **`multi-model-consensus-plan.md`** — optional, opt-in workflow that
    produces three independent candidate plans plus one synthesized
    final plan for high-risk, architectural, or ambiguous issues before
    Judge plan-gate. Does **not** replace the default plan-as-comment
    flow; reach for it only when the extra cost is justified by the
    risk being mitigated. See
    [`docs/guides/multi-model-consensus.md`](../../docs/guides/multi-model-consensus.md)
    for trigger criteria, and
    [`docs/decisions/adr-024-multi-model-consensus-planning.md`](../../docs/decisions/adr-024-multi-model-consensus-planning.md)
    for the prompt-first / no-new-role rationale.
  - **`instruction-compliance-smoke.md`** — no-edit smoke prompt for checking
    startup pointer loading, role-dispatch reasoning, and ADR-026 compliance
    evidence shape before relying on an agent run.
  - **`judge-mode-smoke.md`** — no-edit smoke prompt for Judge PLAN-GATE/DIFF-GATE mode selection and output-format heading conformance (structural heading verification for both modes)
  - **`handshake-and-shape-smoke.md`** — no-edit smoke prompt for session handshake
    positional contract and response-shape verification (Scenarios A–D manual;
    Scenario E automated via `read-profile-compaction-smoke.md`).
  - **`read-profile-compaction-smoke.md`** — AGENTS v25 read profile + post-compaction
    reload smoke (Phases A–C); `scripts/smoke/read-profile-compaction-smoke.sh`.
- **Benchmark prompts** (repo-internal evaluation surfaces) — `model-roi-benchmark-candidate.md`.
  These are controlled benchmark prompts, not downstream project stage prompts.
  - **`model-roi-grader-v1.md`** — locked subjective grader for benchmark score sets;
    outputs JSON matching `.context/benchmarks/model-roi/grading/subjective-grade.schema.json`.
  - **`model-roi-pairwise-grader-v1.md`** — blind pairwise subjective comparison (future rank-stability).
  - **`model-roi-adjudicator-v1.md`** — resolve conflicts between subjective grades using objective evidence.
  - **`model-roi-benchmark-candidate.md`** — canonical candidate prompt for the
    model ROI benchmark tracked in issue `#374`. Reuse the same prompt body across
    aliases; inject only run metadata and the task body. Pair it with
    [`.context/benchmarks/model-roi/README.md`](../../.context/benchmarks/model-roi/README.md)
    the repeatable runbook under
    [`.context/benchmarks/model-roi/benchmark-runbook.md`](../../.context/benchmarks/model-roi/benchmark-runbook.md),
    and task specs under
    [`.context/benchmarks/model-roi/tasks/`](../../.context/benchmarks/model-roi/tasks/).
    Use the runbook to choose the intended benchmark variant before running
    monolithic, context-injected, duo, or orchestration candidates. The documented manual fallback
    after a headless failure is `make worktree` + `make record` from
    `scripts/benchmark/`.
- **Project prompts** (you add these) — `NN-<stage>.md`, one per issue.
  These require Analyst pre-flight before implementation.
  - **`05-implement-benchmark-grading-standardization.md`** — Stage 1E grading
    standardization and canonical regrade wiring on the Phase A feature branch.
  - **`06-implement-class-c-framework-benchmark.md`** — Class C greenfield
    framework benchmark (run on `benchmark/roi` after Phase A merge; defers CP-2).
  - **`07-implement-gemini-free-paid-routing.md`** — Gemini free/paid tier
    routing and benchmark cost-basis metadata (run on `main` after Phase A merge).
  - **`agent-pr-prompts-combined-v2.md`** — bundled five-PR sequence for context
    rules decomposition and non-blocking review workflow (`01`–`04` + optional
    `00-coordinator`); run on `main` after Phase A merge.
    - PR 1 (context decomposition): **merged** via Phase A / AGENTS.md v22.
    - PR 1B (rules consolidation + legacy redirect retirement): **merged** (#380 @
      `864aac1`; AGENTS v23, redirect guide, rule-file slimming, check `048`).
    - PR 2 (advisory review): **merged** (#381 @ `72bd1d9`; `agent-advisory-review.yml`,
      `scripts/workflows/advisory-review/`, Cursor + Antigravity + Gemini).
    - PR 3 (final feedback consolidation): **merged** (#382 @ `e0d845e`; `agent-review-finalize.yml`,
      `scripts/workflows/pr-feedback/`, label `implementation-complete`).
    - PR 4 (post-merge retrospective): **merged** (#383 @ `7e0bf68`; `agent-postmerge-retro.yml`,
      `scripts/workflows/postmerge-retro/`, label `retro-review`).
    - PR 4v2 (daily retro + draft fix PR): **in PR #427** — ADR-030; sandbox smoke pending;
      merge blocked until ADR-029 evidence; then Gemini router prompt `07`.

### Postmortem feedback loop

Two of the shared prompts above implement the v1 downstream-postmortem
feedback loop ratified in [ADR-015](../../docs/decisions/adr-015-postmortem-feedback-loop.md):

- `capture-postmortem.md` — run in a downstream project repo when an
  incident matches the criteria in
  [`docs/postmortems/README.md`](../../docs/postmortems/README.md) →
  "When to write a postmortem". Walks the agent through the template
  with required YAML frontmatter (incl. stack tags) and an explicit
  `What generalizes` decision.
- `mirror-postmortem.md` — run against `mikejmckinney/ai-repo-template`
  to mirror a generalizable downstream postmortem back. Validates the
  source frontmatter, refuses to mirror without a concrete same-PR
  follow-up artifact, and updates the stack-tagged index.

## Frontmatter schema

Every **prompt file** in this directory (every `*.md` other than this
`README.md`) must start with a YAML frontmatter block. `README.md` is an
intentional exception — it documents the schema rather than being a
prompt itself. The frontmatter is what VS Code's prompt picker, Claude
Code's loader, and the `@copilot follow` / `@claude follow` runtimes
consume to surface and dispatch the prompt. Keep the schema minimal so
we don't lock in tool-specific fields prematurely:

```yaml
---
description: <one-line summary of what this prompt does and when to use it>
agent: agent
---
```

Field rules:

- **`description`** (required) — single line, ~140 chars max. Lead with
  the verb (e.g. "Onboard…", "Generate…", "Resolve…"). This is what the
  picker shows; treat it like a short PR title.
- **`agent`** (required) — set to `agent` for now. Reserved for future
  per-prompt role pinning (e.g. `agent: judge`); leave as `agent` unless
  you have a specific reason to override.
- Additional fields (`mode`, `tools`, `model`) — do not add yet. If a
  future tool needs them, propose the addition in an ADR so all four
  prompts stay consistent.

When you add a new prompt, copy this block as the first lines of the
file. The verification check below should print nothing — `README.md`
is filtered out because it is the documented exception:

```bash
for f in .github/prompts/*.md; do
  [ "$(basename "$f")" = "README.md" ] && continue
  head -1 "$f" | grep -q '^---$' || echo "missing frontmatter: $f"
done
```
