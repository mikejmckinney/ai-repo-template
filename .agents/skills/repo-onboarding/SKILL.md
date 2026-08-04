---
name: repo-onboarding
description: |
  Classify and onboard an agent to an unfamiliar repository, bootstrap a
  derived ai-repo-template project, or rebuild a missing or stale
  AI_REPO_GUIDE.md. Use for first-clone orientation and explicit repository
  onboarding, not session recovery or cross-platform transcript import.
compatibility: opencode
---

# Repository Onboarding

Build an evidence-based model of the current repository before implementation.
This skill owns repository classification, optional template bootstrap,
orientation, and repository briefs. It does not recover session history or
import another platform's transcript.

## Classify First

Run the read-only classifier:

```bash
.agents/skills/repo-onboarding/scripts/classify-mode.sh --repo "$PWD"
```

Modes:

- **`ai-repo-template`**: the canonical template or legacy dotfiles repository. Preserve
  canonical template documentation and skip seed onboarding.
- **`template-seed`**: a derived repository whose versioned lifecycle state says
  evidence-based onboarding is still required.
- **`complete`**: a derived repository that is already onboarded, including
  legacy repositories without lifecycle state. Skip seed onboarding.

Canonical template identity takes precedence over lifecycle state. Placeholder
text and retained template resources never select a mode. Do not regenerate the
template's canonical documentation.

## Select One Path

Mode `ai-repo-template` or `complete`:

1. Read `references/repository-orientation.md`.
2. Inspect current issue/PR coordination state when a task is assigned.
3. Produce the repository brief defined in `references/repo-brief-template.md`.
4. Update `AI_REPO_GUIDE.md` only when missing or demonstrably stale.

Do not run `scripts/setup.sh` for `ai-repo-template` or `complete` orientation.
Those paths gather evidence and must not introduce setup side effects.

Mode `template-seed`:

1. Read `references/template-seed.md`.
2. Confirm that onboarding changes were explicitly requested before editing.
3. Complete the inspect-and-adapt sequence in order. Its setup phase runs once
   and stops onboarding on failure.
4. Set lifecycle state to `complete`, run final validation, and produce the
   repository brief.

Do not load the `template-seed` reference for other modes.

## Safety Boundary

Classification and validation scripts are read-only. `template-seed` onboarding
may edit repository resources, but retained template content is not a defect.
Extend, replace, or delete only when current project evidence requires it, and
never perform destructive changes from implicit authorization.

- Verify file contents; do not guess project identity or architecture.
- Preserve unrelated user changes in a dirty worktree.
- Prefer small, reviewable edits.
- Do not implement an application task during onboarding.
- Do not treat historical transcript context as current repository evidence.
- Current files, Git state, and live issue/PR state are authoritative.

## Validate

After orientation or bootstrap, run:

```bash
.agents/skills/repo-onboarding/scripts/validate-onboarding.sh --repo "$PWD"
```

The command emits JSON:

```json
{
  "status": "success",
  "mode": "complete",
  "stable": true,
  "blocking_findings": [],
  "warnings": []
}
```

It exits nonzero when onboarding blockers remain. Warnings identify optional
orientation or environment checks that could not be completed.

## Completion Contract

Report:

```text
Context reviewed. Onboarding Mode: <ai-repo-template|template-seed|complete>.
Repository: <canonical root or origin>. Current task is <name or none>.
Environment is <Stable|Unstable: reason>. Ready for instructions.
```

Also provide the concise repository brief, commands actually verified, known
risks, and any files changed during `template-seed` onboarding or guide repair.
This completion report is the session-local onboarding receipt. Do not create a
second committed live-state artifact for the receipt.

Stop when classification is ambiguous, `template-seed` lacks explicit authorization,
required current sources are unavailable, or validation reports blockers that
cannot be resolved safely.
