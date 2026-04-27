---
description: Onboard an AI agent to a repo (template-clone or existing). Builds a repo brief, regenerates template-owned docs when needed, and chains to copilot-onboarding.md.
agent: agent
---

# Repository Onboarding Prompt

You are a senior software engineer joining an existing codebase. Your job is to build an accurate mental model of this repo BEFORE making changes, then implement the requested work with minimal, well-tested diffs.

## Core Principles

- **Do NOT guess** APIs, file contents, or behavior. Verify everything in the repo.
- **Prefer small, reversible changes**. Keep style consistent with the repo.
- **Before editing**: Summarize understanding → propose a plan → identify files to touch.
- **After editing**: Provide rationale, the diff, and exact commands to test.

---

# Phase 0: Template Bootstrap (skip if not a fresh template clone)

This phase only applies when the repo was just cloned from
`mikejmckinney/ai-repo-template` (or its predecessor `dotfiles`) and has not
yet been customized for the actual project. If none of the detection signals
below fire, skip directly to Phase 1.

## Step 0.1: Detect template state

Run these checks (any one positive ⇒ template-bootstrap mode):

- `git remote -v` shows the repo name is `ai-repo-template` itself
  (the template repo — do NOT regenerate; skip to Phase 1).
- `README.md` or `AI_REPO_GUIDE.md` contains `TEMPLATE_PLACEHOLDER`.
- `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`.
- `grep -RIl TEMPLATE_PLACEHOLDER .` returns one or more matches outside
  `.github/prompts/` (which legitimately documents the marker).

## Step 0.2: Apply template-bootstrap rules

Do NOT duplicate the rules here — they live in **`.github/copilot-instructions.md`**
(“Template detection” block) and **`AGENTS.md`** (“Template detection” section).
Read both, then follow them. The short version:

1. **Replace `README.md`** with project-specific content (delete the template
   stub language; preserve repo-specific structure if any already exists).
2. **Regenerate `AI_REPO_GUIDE.md`** from the repo's real assets
   (`./.context/**`, `./docs/**`, source). This file is canonical for agents
   and must not retain template placeholder language.
3. **Replace placeholders** wherever they occur:
   - `TEMPLATE_PLACEHOLDER` markers → project-specific text or remove.
   - `PLEASE_UPDATE_THIS/URL` in `.github/ISSUE_TEMPLATE/config.yml` →
     actual `owner/repo` from `git remote -v`.
4. **Extend `.context/rules/agent_ownership.md`** with rows for the project's
   real source paths (e.g. `src/frontend/**`, `src/backend/**`, `tests/**`).
   Do NOT remove the template-governance roles
   (Analyst / Architect / PM / QA / DevOps / Docs / Judge / Critic) —
   they remain load-bearing.
5. **Customize `docs/FAQ.md`** — strip entries prefixed with `Template:` and
   replace with project-specific Q&A.

When Phase 0 work is complete, continue to Phase 1.

---

# Phase 1: Build Context (Repo Brief)

## Step 1.0: Quick context check (always run first)

Before the deep dive in Step 1.1, do a fast sanity pass so the rest of
Phase 1 has accurate state:

1. Read `.context/state/_active.md` (note the leading underscore) or any
   `.context/state/task_*.md` to understand the immediate goal.
2. Read `.context/00_INDEX.md` to locate relevant rules and constraints.
3. Run `git status` and `./scripts/verify-env.sh` to confirm the working
   tree and environment are stable.
4. Skim `.context/sessions/latest_summary.md` for recent decisions and
   handoffs from prior sessions.
5. Report a one-line status:
   `"Context reviewed. Current task is <name>. Environment is <Stable|Unstable: <reason>>. Ready for instructions."`

**"Stable" means all of:**

- `git status` is clean, or only contains expected agent edits.
- `./scripts/verify-env.sh` exits 0 **and** reports no onboarding-blocking
  WARNs. In particular, treat any `TEMPLATE_PLACEHOLDER`-still-present
  WARN as **Unstable** when running in a derived (non-template) repo —
  it means stub docs haven't been replaced yet (Phase 0 is incomplete).
- Phase 1 below completed without missing-file errors. (`bash test.sh`
  is the deeper structural check.)

Otherwise report **Unstable** and name the specific failure or blocking
WARN (e.g. `Unstable: verify-env.sh exited 1 — missing PYTHONPATH`, or
`Unstable: verify-env.sh warned TEMPLATE_PLACEHOLDER remains in 3 files`).

If any of these files are missing, note it explicitly — do not invent
content, and do not block on it. Continue with the rest of Phase 1.


## Step 1.1: Read Key Documentation

- [ ] `README.md`
- [ ] `CONTRIBUTING.md`
- [ ] `AI_REPO_GUIDE.md` (if exists — treat as canonical)
- [ ] `.github/copilot-instructions.md` (if exists)
- [ ] Any docs in `/docs`, `ARCHITECTURE.md`, `SECURITY.md`

## Step 1.2: Map the Codebase

Use search and file exploration (not linear reading) to identify:

### Directory Structure
```
Top-level directories and their purposes:
├── src/           # <purpose>
├── tests/         # <purpose>
├── docs/          # <purpose>
└── ...
```

### Entry Points
- **Web apps**: Main server file, routers, app bootstrap
- **CLI**: Bin directory, command registry
- **Libraries**: Public API surface, exports

### Test Infrastructure
- Test framework used
- Test file locations
- How to run tests

## Step 1.3: Identify Build Commands

Find and verify these commands from `package.json`, `Makefile`, `pyproject.toml`, etc.:

| Task | Command | Verified |
|------|---------|----------|
| Install dependencies | | [ ] |
| Build | | [ ] |
| Test | | [ ] |
| Lint | | [ ] |
| Type check | | [ ] |

## Step 1.4: Produce Repo Brief

Output a structured summary:

```markdown
## What This Repo Does
<1-3 sentences>

## Tech Stack
- Language: 
- Framework:
- Build tool:
- Test framework:

## Folder Map
- `/src` — 
- `/tests` — 
- `/docs` — 

## Key Entry Points
- Main: 
- CLI: 
- API: 

## Configuration Files
- Build config:
- Lint config:
- CI config:

## How to Run Locally
<commands>

## How to Test
<commands>

## Known Risks/Gotchas
- <item>
```

## Step 1.5: Create/Update AI_REPO_GUIDE.md

If `/AI_REPO_GUIDE.md` does NOT exist, create it with:
- Overview (what this is)
- Quickstart (run/test commands)
- Folder map + key entry points
- Conventions (lint/format, branching, commit style)
- Where to add things (routes, services, components)
- Troubleshooting / common gotchas

If it exists, verify accuracy and update if needed.

## Step 1.6: Confirm template placeholders are gone

Template-placeholder cleanup is handled in **Phase 0**. As a final check,
run `grep -RIl 'TEMPLATE_PLACEHOLDER\|PLEASE_UPDATE_THIS' .` and confirm
the only remaining matches are inside `.github/prompts/` (which
legitimately documents the markers). If matches appear elsewhere, return
to Phase 0 Step 0.2 and finish the cleanup before continuing.

---

# Phase 2: Clarify the Task

Ask at most **3 targeted questions** that unblock implementation.

If no questions are required, proceed to Phase 3.

Examples of good questions:
- "Should this change be backward compatible?"
- "Which test file should I add tests to?"
- "Is there an existing pattern for <X> I should follow?"

---

# Phase 3: Implement

## Step 3.1: Re-read AI_REPO_GUIDE.md

Cite which sections guide your approach.

## Step 3.2: Propose a Plan

Before making changes, provide:

```markdown
## Implementation Plan

### Changes
1. [ ] `path/to/file.ext` — <what changes>
2. [ ] `path/to/file.ext` — <what changes>

### Tests to Add/Update
- [ ] `test/path/file.test.ext` — <what to test>

### Risks
- <potential issues>

### Verification
- `<command>` — what it proves
```

## Step 3.3: Make the Changes

- Follow existing code style and patterns
- Add/update tests for behavioral changes
- Update docs if behavior changed

## Step 3.4: Update AI_REPO_GUIDE.md

If your changes affect:
- Commands
- File structure
- Conventions
- Entry points

Update `AI_REPO_GUIDE.md` to reflect this.

---

# Phase 4: Deliver

Provide:

````markdown
## Summary
<What changed and why>

## Files Changed
- `path/to/file.ext` — <description>

## Test Commands
```bash
<commands to verify changes work>
```

## Expected Outcome
<What should happen when tests pass>

## AI_REPO_GUIDE.md Status
- [ ] Up to date
- [ ] Updated (describe what changed)
- [ ] N/A (no structural changes)

## Follow-ups (optional)
- <Future improvements>
````

---

# Verification Checklist

Before considering the task complete:

- [ ] All tests pass
- [ ] Linting passes
- [ ] Build succeeds
- [ ] Changes are minimal (no unrelated modifications)
- [ ] Docs updated if behavior changed
- [ ] `AI_REPO_GUIDE.md` is accurate

---

# Next: Generate Copilot Instructions

When onboarding is finished (especially after a Phase 0 bootstrap), chain
into **`.github/prompts/copilot-onboarding.md`** to generate or refresh
`.github/copilot-instructions.md` so Copilot's per-repo context matches
the new project shape. Skip this step only if `copilot-instructions.md`
is already accurate for the post-onboarding state.
