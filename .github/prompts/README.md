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
    positional contract and response-shape verification: tests parent vs subagent
    handshake positioning, exact-output first-line contract (Judge `DECISION:`,
    Critic `CRITIC DECISION:`), and `## Subagent context receipt` placement (4 scenarios)
- **Project prompts** (you add these) — `NN-<stage>.md`, one per issue.
  These require Analyst pre-flight before implementation.

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
