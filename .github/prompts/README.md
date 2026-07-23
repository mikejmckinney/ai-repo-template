# Prompt Catalog

The active prompt set supports one monolithic implementing agent plus normally
applied, label-gated, non-blocking advisory review and recurring retro automation.

| Prompt | Purpose |
|---|---|
| `shared-review-lenses.md` | Canonical review criteria used by advisory and retro |
| `pr-advisory-review.md` | Rolling in-progress PR advisory snapshot |
| `post-merge-retro.md` | Daily merged-PR structured review |
| `post-merge-retro-fix.md` | Daily batch fix pass |
| `weekly-repo-review.md` | Weekly full-repository structured review |
| `weekly-repo-review-fix.md` | Weekly batch fix pass |
| `capture-postmortem.md` | Capture a downstream lesson |
| `mirror-postmortem.md` | Mirror a generalized postmortem upstream |

ADR-031 retired role-specific, pre-push, formal-review resolution, finalization,
and legacy consensus-planning prompts. Use the OpenCode `multi-model-consensus` skill
for explicit independent multi-model review.

Model-ROI benchmark and grading prompts live on `benchmark/roi`; they are
evaluation-lab inputs rather than template runtime prompts.
