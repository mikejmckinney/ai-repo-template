# Prompts Directory

Prompt files referenced from GitHub issues and PR comments.

## Before writing a new project prompt

Project prompts (like `NN-<stage>.md`) are validated by the **Analyst role**
before any implementation starts. Analyst applies the "15-minute test" from
[`.github/agents/analyst.agent.md`](../agents/analyst.agent.md) →
"Prompt Pre-Flight Validation":

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
  `repo-onboarding.md`, `copilot-onboarding.md`, `expand-backlog-entry.md`.
  These describe procedures, not deliverables, and don't require pre-flight.
- **Project prompts** (you add these) — `NN-<stage>.md`, one per issue.
  These require Analyst pre-flight before implementation.
