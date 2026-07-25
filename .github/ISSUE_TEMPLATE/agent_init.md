---
name: Agent Initialization
about: Initialize a new repository from this template
title: '[INIT] Initialize repository from template'
labels: setup, agent-task
assignees: ''
---

## Repository Initialization Task

This repository was created from the `ai-repo-template`. Please initialize it for the actual project.

## User outcome (15-minute test)

<!--
Optional but recommended. If you can answer this clearly here, add the
`outcome-validated` label to record that the user outcome is explicit.

The test: "If a user spent 15 minutes with the initialized repo, what
would they be able to DO?" Focus on user actions (run, build, deploy,
onboard), not files created.
-->

## Truth Hierarchy

Use this priority order when information conflicts:
1. Current assigned issue and linked PR
2. `AGENTS.md`
3. `./.context/**`
4. `./docs/**`
5. Codebase

## Preflight Checks

- [ ] Verify `.context/00_INDEX.md` exists
- [ ] Verify the OpenCode `repo-onboarding` skill is available
- [ ] Inspect `.context/onboarding-state.json` and run the onboarding classifier
- [ ] Run `git remote -v` to detect repository owner/name

## Initialization Steps

### 1. Understand the Project

Determine the project purpose and current status from:
- `.context/**`
- `docs/**`
- Existing codebase (if any)

### 2. Run Repository Onboarding

Execute the OpenCode `repo-onboarding` skill and follow its classified mode.
Make evidence-backed onboarding edits only when the classifier returns
`template-seed`; `ai-repo-template` and `complete` require orientation only.

### 3. Update README.md

- Preserve useful README structure and revise only where project evidence requires it

Include:
- Project name and description
- Setup instructions
- Usage examples
- Tech stack
- `## Limitations` — known constraints of the project
- `## Future Improvements` — forward-looking items not on the active roadmap
- `## FAQ` — short section or link to `docs/FAQ.md`

### 4. Customize docs/FAQ.md

- Preserve useful template entries and revise only those contradicted by project evidence
- Add project-specific questions surfaced during onboarding
- If the project will keep the FAQ in README instead, delete `docs/FAQ.md`

### 5. Regenerate AI_REPO_GUIDE.md

Create a new AI_REPO_GUIDE.md for THIS repo (not the template), including:
- Project summary
- Where canonical truth lives (`.context/00_INDEX.md`)
- How to use the context pack
- Repo conventions
- Build/test/lint commands
- Next steps

### 6. Verify Repository Checks

Update `.github/workflows/ci-tests.yml`:
- Preserve the repository checks already in use
- Add project-specific build, lint, typecheck, and test commands only when the
  detected stack defines them

### 7. Fill in Context Pack

Update `.context/` files:
- `00_INDEX.md` — project summary and key decisions
- `roadmap.md` — shipped milestones and issue-backed future work
- `state/agent_state_comment_template.md` — copy into issues/PRs for live agent state when work begins
- For verified UI work only, generate root `DESIGN.md` with the onboarding
  helper and replace bracketed prompts from product evidence

### 8. Configure Secrets (if needed)

Document any required repository secrets:
- API keys, database URLs, etc.

## Important Notes

- Do not broadly reset `.context/**`; modify only evidence-backed project state
- Propose changes via comments if you see issues
- Run `./test.sh` to verify template integrity after changes

## Project Details

<!-- Fill in if known -->

**Project Name**: 
**Description**: 
**Tech Stack**: 
**Primary Language**: 

<!-- implementation-plan:v2:begin -->

## Implementation Plan

### Outcome

### Approach

### Files to change

- [`README.md`](../blob/main/README.md) — <one phrase: what change>
- [`scripts/tests/`](../tree/main/scripts/tests) — <one phrase: what change>

<!-- Replace the examples with every expected file or directory. Existing files
and directories must be clickable: use ../blob/main/<path> for a file and
../tree/main/<path> for a directory. For a planned new path, link its nearest
existing parent and label the new path in the description. For a glob, link its
containing directory and keep the glob in the link text or description. -->

### User outcome validation plan — PRIMARY

For each material claim, plan one auditable record:

```text
Material claim:
Core user action:
Irreducible side effect:
Cost / authorization: <none, explicitly approved boundary, or blocked pending approval>
Environment:
Why representative:
Implementation SHA:
Action performed:
Expected result:
Observed result:
Artifact:
Artifact type:
Redaction:
Retention:
Evidence reuse: <none, or Paths: <later path analysis>; Conditions: <load-bearing condition analysis>>
Result: pass | fail | blocked
```

Use the least costly outcome-equivalent environment without removing or
redefining the core user action or side effect. Paid or destructive actions
require explicit approval and remain blocked until performed. Mixed changes may
require more than one record. External-state and runtime claims cannot be prose-only.
See `docs/guides/outcome-validation.md`.

### Supporting verification

**Change class**: <code-or-docs | pull_request-triggered workflow | default-branch-only workflow | mixed>

The classifier owns workflow-trigger facts. Select outcome environments from
the user journey; use the sibling sandbox adapter only when GitHub default-branch
state is load-bearing.

### Risks / out-of-scope

### Opportunity notes

### Revision history

- Not yet planned.

<!-- implementation-plan:v2:end -->
