# Process Rule: Documentation Maintenance Triggers

> **Purpose**: When you change one part of the repo, certain other docs must
> change in the same PR (or you must explicitly state why no update is
> required). This rule encodes the trigger map so the requirement isn't
> scattered across `AGENTS.md`, role files, and tribal knowledge.

This is a **process rule**, not a domain rule. It applies to every role and
every PR.

## Hard rule

If your PR matches a row in the trigger table below, the listed companion
file(s) must be updated in the same PR — or the PR description must
contain the explicit phrase
`<companion-file>: no changes required` and a one-line justification.

Judge enforces this at diff-gate (see
`.github/agents/judge.agent.md` → "Doc trigger check").

## Trigger table

| If you change … | You must update (same PR) | Why |
|---|---|---|
| Build / test / lint / run / install commands, layout, entry points, configs, conventions, troubleshooting | `AI_REPO_GUIDE.md` | Canonical agent map; stale = silent breakage |
| A previously documented architectural decision | The existing ADR's `Status: Superseded by ADR-NNN` line **and** a new ADR explaining the change | ADR history is the audit trail; supersession must be explicit |
| A postmortem under `docs/postmortems/**` whose "What generalizes" field is **Yes** | A follow-up issue, PR, ADR, or rule edit cited from the postmortem's Action Items **in the same PR** (or, if that follow-up is genuinely out of scope for this PR, an already-open issue linked from Action Items — state the issue number in the PR description under `docs/postmortems/: deferred to #NNN`) | A postmortem alone changes nothing; the lesson only lands when a rule/prompt/ADR/issue ships. Deferral is allowed but must be explicit so Judge can verify the audit trail |
| Multi-agent flow, role boundaries, state machine, or coordination protocol | `docs/guides/multi-agent-coordination.md` | Single source of truth for the workflow |
| Add / remove / re-scope a role | `.github/agents/<role>.agent.md` **and** `.claude/agents/<role>.md` (mirror) **and** `.context/rules/agent_ownership.md` **and** `install.sh` (`MULTIAGENT_FILES`) **and** `test.sh` (`REQUIRED_FILES`) **and** `docs/guides/multi-agent-coordination.md` (role table) | The two-registry design (ADR-003) breaks silently if any mirror is missing |
| A new immutable constraint or domain rule | New file under `.context/rules/<file>.md` and link from `.context/rules/README.md` | Rules live in one directory by convention |
| A canonical prompt under `.github/prompts/*.md` that is duplicated as inline prompt text inside a workflow file (e.g., `pr-resolve-all.md` is mirrored in `agent-fix-reviews.yml` and `agent-relay-reviews.yml`) | Every inline mirror in the same PR | Prompt-file edits without inline-mirror updates have already caused real regressions (PR #95 → #96 → #97 phase-ordering bug) |
| Add a pipeline label to `docs/guides/agent-pipeline.md`'s label table | `scripts/setup.sh` `_ensure_label` list (and the fallback warning's manual-label list in the same script) | Labels documented but not auto-created cause silent setup drift |
| Add or remove a top-level template file expected on every install | `test.sh` `REQUIRED_FILES` (or `CONTEXT_FILES` / `DOCS_FILES`) **and** `install.sh` if it ships from the dotfiles install | `test.sh` is the only enforcement gate |
| Change cadence / format of `.context/state/_active.md`, `task_*.md`, `handoff_*.md`, or `sessions/latest_summary.md` | `.context/state/README.md` (or `.context/sessions/README.md`) and the affected templates | These files are agent-consumed; format drift breaks parsing |

## Soft rule

If you find yourself repeatedly writing
`<companion-file>: no changes required` for the same change shape, the
trigger table is wrong — propose a row change in a separate PR rather
than papering over it.

## How to declare "no changes required"

Add a line to your PR description like:

```
AI_REPO_GUIDE.md: no changes required (only edited a single ADR; layout
and commands unchanged)
```

Judge accepts this as satisfying the trigger; Critic may still flag it if
the justification looks weak.
