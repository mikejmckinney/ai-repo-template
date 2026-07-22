# Template Seed Onboarding

`template-seed` means a derived repository has not completed its initial
evidence-based orientation. Confirm explicit authorization before editing and
preserve unrelated worktree changes.

## Inspect And Adapt

1. Read the current application, documentation, context, and configuration
   before deciding what needs to change.
2. Preserve template resources that accurately support the derived project.
3. Extend resources when project-specific detail is missing but the existing
   structure remains useful.
4. Replace or delete content only when current evidence shows it is incorrect,
   obsolete, or incompatible with the project outcome.
5. Regenerate `AI_REPO_GUIDE.md` only when it is missing or demonstrably stale.
6. Update repository URLs, build/test commands, context, and ownership rules
   only after verifying their project-specific values.
7. Obtain explicit authorization before destructive edits or broad resets.
8. Set `.context/onboarding-state.json` to `status: "complete"` only after
   orientation and validation succeed.

## Verification

Run `scripts/verify-env.sh` and the onboarding validator. Resolve actual
environment and required-file blockers before continuing; retained template
content is not independently blocking.

Do not create local claim boards or checked-in handoff scaffolding. Live
coordination remains in assigned GitHub issue/PR state.
