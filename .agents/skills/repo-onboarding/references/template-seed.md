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
8. When verified application files or the assigned outcome establish UI work,
   run `scripts/create-design-contract.sh --repo "$PWD"` and replace its
   bracketed prompts from product evidence before frontend implementation.
   Do not create root `DESIGN.md` for backend-only, infrastructure-only, or
   documentation repositories.
9. After project-specific adaptation, run `scripts/setup.sh` from the repository
   root. It owns dependency installation, build setup, repository labels,
   secret-presence reporting, and the final `scripts/verify-env.sh` phase.
   If setup fails, stop and leave lifecycle state as `template-seed`.
10. After setup succeeds, set `.context/onboarding-state.json` to
    `status: "complete"`, then run the onboarding validator as the final state
    check.

## Verification

Run `scripts/setup.sh` and the onboarding validator. Resolve actual setup,
environment, and required-file blockers before continuing; retained template
content is not independently blocking.

Do not create local claim boards or checked-in handoff scaffolding. Live
coordination remains in assigned GitHub issue/PR state.
