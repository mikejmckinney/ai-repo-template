# Prompt Catalog

The active prompt set supports one monolithic implementing agent plus optional
review automation.

| Prompt | Purpose |
|---|---|
| `repo-onboarding.md` | Classify and initialize a repository |
| `op-issue-workflow.md` | Issue-to-merge implementation procedure |
| `expand-backlog-entry.md` | Expand sparse backlog entries without inventing requirements |
| `shared-review-lenses.md` | Canonical review criteria used by advisory and retro |
| `pr-advisory-review.md` | Optional in-progress PR advisory snapshot |
| `post-merge-retro.md` | Daily merged-PR structured review |
| `post-merge-retro-fix.md` | Daily batch fix pass |
| `weekly-repo-review.md` | Weekly full-repository structured review |
| `weekly-repo-review-fix.md` | Weekly batch fix pass |
| `capture-postmortem.md` | Capture a downstream lesson |
| `mirror-postmortem.md` | Mirror a generalized postmortem upstream |
| `model-roi-*.md` | Benchmark and grading prompts |

ADR-032 retired role-specific, pre-push, formal-review resolution, finalization,
and legacy consensus-planning prompts. Use the OpenCode `local-consensus` skill
for explicit independent multi-model review.
