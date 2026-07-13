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
.opencode/skills/repo-onboarding/scripts/classify-mode.sh --repo "$PWD"
```

Modes:

- **A**: the ai-repo-template or legacy dotfiles repository itself. Preserve
  canonical template documentation and skip bootstrap.
- **B**: a derived repository with unresolved template/bootstrap signals.
- **C**: a derived repository that is already customized. Skip bootstrap.

Mode A takes precedence when template identity and placeholder signals
conflict. Do not regenerate the template's canonical documentation.

## Select One Path

Mode A or C:

1. Read `references/repository-orientation.md`.
2. Inspect current issue/PR coordination state when a task is assigned.
3. Produce the repository brief defined in `references/repo-brief-template.md`.
4. Update `AI_REPO_GUIDE.md` only when missing or demonstrably stale.

Mode B:

1. Read `references/bootstrap-mode-b.md`.
2. Confirm that bootstrap changes were explicitly requested before editing.
3. Complete the reset and repopulation sequence in order.
4. Continue with repository orientation and the repository brief.

Do not load the Mode B reference for Mode A or C.

## Safety Boundary

Classification and validation scripts are read-only. Mode B itself is not:
it rewrites project documentation, resets historical template state, and
deletes template-only diagrams. Never perform Mode B changes based only on a
weak signal or implicit request.

- Verify file contents; do not guess project identity or architecture.
- Preserve unrelated user changes in a dirty worktree.
- Prefer small, reviewable edits.
- Do not implement an application task during onboarding.
- Do not treat historical transcript context as current repository evidence.
- Current files, Git state, and live issue/PR state are authoritative.

## Validate

After orientation or bootstrap, run:

```bash
.opencode/skills/repo-onboarding/scripts/validate-onboarding.sh --repo "$PWD"
```

The command emits JSON:

```json
{
  "status": "success",
  "mode": "C",
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
Context reviewed. Onboarding Mode: <A|B|C>. Current task is <name or none>.
Environment is <Stable|Unstable: reason>. Ready for instructions.
```

Also provide the concise repository brief, commands actually verified, known
risks, and any files changed during Mode B bootstrap or guide repair.

Stop when classification is ambiguous, Mode B lacks explicit authorization,
required current sources are unavailable, or validation reports blockers that
cannot be resolved safely.

The standalone cross-platform procedure remains at
`.github/prompts/repo-onboarding.md` for agents without OpenCode skills.
