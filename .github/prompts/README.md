# Prompts Directory

Prompt files referenced from GitHub issues and PR comments.

## Before writing a new project prompt

Project prompts (like `NN-<stage>.md`) are validated by the **Analyst role**
before any implementation starts. Analyst applies the "15-minute test" from
[`.github/agents/analyst.agent.md`](../agents/analyst.agent.md) →
"Pre-Flight Validation":

> If the intended audience spent 15 minutes with the final deliverable,
> would they *experience* the outcome, or would they *read about* it?

Prompts that list deliverables without specifying the user outcome fail
pre-flight. The most common failure: describing 6 React pages instead of
describing what a user will be able to *do* with those pages.

Lead your prompt with **Client-facing outcomes** (concrete user actions)
and **Non-negotiables** (things that must be real, not mocked). File
lists come after, not before.

## When to apply `gate:preflight-required` to non-prompt issues

Per ADR-014, the Pre-Flight gate also fires on issues carrying the
`gate:preflight-required` label, even when no prompt file is referenced.
Apply this label when filing:

- An ad-hoc feature issue (no `NN-*.md` reference) that proposes a UI,
  service, pipeline, dataset, or operational artifact.
- An ADR proposal that introduces a new agent surface (new role, new
  gate, new pipeline phase, new automation surface).
- Chat-originated work where the conversation is the only place the
  user outcome was discussed and the issue body alone wouldn't pass
  pre-flight.

If you're unsure whether the label applies, apply it. False-positive
cost is one Pre-Flight Report; false-negative cost is rework of the
wrong artifact. The label generally does not apply to bug fixes,
dependency bumps, typo corrections, doc edits, or shared procedural
prompts unless an author explicitly opts in with
`gate:preflight-required` — those default carve-outs are preserved from
ADR-005.

## Files here

- **Shared procedural prompts** (template-provided; e.g.) — `pr-resolve-all.md`,
  `repo-onboarding.md`, `copilot-onboarding.md`, `expand-backlog-entry.md`.
  These describe procedures, not deliverables, and don't require pre-flight.
- **Project prompts** (you add these) — `NN-<stage>.md`, one per issue.
  These require Analyst pre-flight before implementation.

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
