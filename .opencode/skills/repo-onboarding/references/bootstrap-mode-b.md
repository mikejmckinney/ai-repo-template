# Mode B Bootstrap

Mode B is a destructive repository-customization workflow. Confirm explicit
authorization before editing and preserve unrelated worktree changes.

## Reset And Repopulate

1. Replace template content in `README.md` with project-specific documentation.
2. Reset and repopulate `.context/00_INDEX.md`, `.context/roadmap.md`, and
   `.context/vision/README.md` from actual project evidence.
3. Update `DESIGN.md` with project-specific design direction.
4. Regenerate `AI_REPO_GUIDE.md` only after context files reflect the project.
5. Remove `Template:` FAQ entries and add relevant project Q&A.
6. Delete template-only diagrams:
   - `.context/vision/architecture/multi-agent-flow.md`
   - `.context/vision/architecture/state-surfaces.md`
7. Reset `.context/sessions/latest_summary.md` to `No sessions yet`; retain
   reusable state/session templates and directory README files.
8. Replace `PLEASE_UPDATE_THIS/URL` in the issue-template configuration with
   the verified repository path.
9. Extend agent ownership for real source and test paths without deleting
   template-governance roles.

## Verification

Run `scripts/verify-env.sh` and the onboarding validator. Resolve every
blocking placeholder, template identity, missing required file, and
template-only diagram finding before continuing.

Do not create local claim boards or checked-in handoff scaffolding. Live
coordination remains in assigned GitHub issue/PR state.
