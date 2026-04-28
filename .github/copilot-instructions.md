# GitHub Copilot — repository instructions

> **Read [`AGENTS.md`](../AGENTS.md) first.** It is the single source of truth
> for agent instructions in this repo. This file points at the AGENTS.md
> sections Copilot needs and carries only Copilot-specific behavior inline.

## Pointers into AGENTS.md

| Topic | Section in `AGENTS.md` |
|---|---|
| Repo-template vs. derived-repo behavior | `## Template detection (important)` |
| Conflict resolution between `.context/`, `docs/`, codebase | `## Truth hierarchy` |
| What to read on session start | `## Onboarding procedure` |
| Pre-flight gate before implementing user-facing deliverables | `### Analyst pre-flight gate (REQUIRED before implementation)` |
| Implementation-plan-as-comment requirement | `### Plan-as-comment requirement (REQUIRED before implementation)` |
| Issue / PR template usage when filing programmatically | `## Templates and conventions` |
| Critical-thinking and citation expectations | `## Critical thinking and communication` |
| Verification commands before declaring done | `## Validation` |

If a Copilot review or coding session conflicts with anything above, AGENTS.md wins.

## Following referenced prompt files (Copilot-specific)

When a comment or issue body contains `@copilot follow <path>` (e.g.
`@copilot follow .github/prompts/pr-resolve-all.md`):

1. Only the first `@copilot follow <path>` per comment is processed. If the
   path doesn't exist or isn't under `.github/prompts/`, post a single
   comment explaining and stop.
2. Read the entire file at `<path>` before anything else.
3. Treat its contents as primary task instructions, overriding shorter
   instructions in the mention.
4. Execute every phase/step in order. Do not skip phases.
5. If the file's "Rules" or "Verification" section conflicts with defaults
   elsewhere in this repo, the referenced file wins for this task.
6. If your cumulative response would exceed GitHub's per-comment limit
   (~65 KB), split across sequential comments labeled `Part 1/N`,
   `Part 2/N`, ... rather than truncating. Post each part as soon as ready.

Mirrors the `@claude follow <path>` convention in `.github/workflows/claude.yml`.

## Why a pointer and not a full copy

This file used to duplicate large sections of AGENTS.md verbatim. Experiment
[#208](https://github.com/mikejmckinney/ai-repo-template/issues/208) confirmed
Copilot follows markdown references from this file to other repo files, so
duplicating content only buys drift cost. [`CLAUDE.md`](../CLAUDE.md) uses the
same pointer pattern for the same reason.

When AGENTS.md headings change, the pointer table above must be updated in the
same PR — see `.context/rules/process_doc_maintenance.md`.
