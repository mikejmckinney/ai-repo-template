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
`.agents/judge.md` → "Doc trigger check").

## Trigger table

| If you change … | You must update (same PR) | Why |
|---|---|---|
| Build / test / lint / run / install commands, layout, entry points, configs, conventions, troubleshooting | `AI_REPO_GUIDE.md` | Canonical agent map; stale = silent breakage |
| A previously documented architectural decision | The existing ADR's `Status:` line (`Superseded by ADR-NNN` for a full replacement, or `Accepted (superseded in part by ADR-NNN)` for a partial one) **and** a new ADR explaining the change **and** `docs/decisions/README.md` | ADR history and the human ADR index are the audit trail; supersession must be explicit in both places |
| A postmortem under `docs/postmortems/**` whose "What generalizes" field is **Yes** | A follow-up issue, PR, ADR, or rule edit cited from the postmortem's Action Items **in the same PR** (or, if that follow-up is genuinely out of scope for this PR, an already-open issue linked from Action Items — state the issue number in the PR description under `docs/postmortems/: deferred to #NNN`) | A postmortem alone changes nothing; the lesson only lands when a rule/prompt/ADR/issue ships. Deferral is allowed but must be explicit so Judge can verify the audit trail |
| Multi-agent flow, role boundaries, state machine, or coordination protocol | `docs/guides/multi-agent-coordination.md` | Single source of truth for the workflow |
| Add / remove / re-scope a role | `.agents/<role>.md` (canonical body) **and** `.github/agents/<role>.agent.md` (Copilot overlay) **and** `.claude/agents/<role>.md` (Claude overlay) **and** `.context/rules/agent_ownership.md` **and** `install.sh` (`MULTIAGENT_FILES`) **and** `test.sh` (`REQUIRED_FILES`) **and** `docs/guides/multi-agent-coordination.md` (role table) | The canonical-plus-overlays design (ADR-023) breaks silently if any file is missing; the N-way parity check in `scripts/checks/050-agent-mirror.sh` will fail loudly |
| Add a new platform (Cursor, Gemini CLI, etc.) | `scripts/checks/050-agent-mirror.sh` (append one element to each parallel array — `platforms`, `overlay_dirs`, `overlay_suffixes`, `model_allowlist_res`, `model_required_flags` — at the same index) **and** one overlay per role under the new platform's folder **and** `.context/rules/process_model_tier.md` if the new platform's model value-space differs from the existing allowlists | The N-way parity check is array-driven by design (ADR-023); without an entry in every parallel array the new platform's overlays are silently skipped, and without a model allowlist the script fails closed on every overlay |
| Change the model tiering policy (ADR-019 — add/remove an allowed model string, change the per-platform value-space format) | `scripts/checks/050-agent-mirror.sh` (`copilot_allowlist_re` and/or `claude_allowlist_re` regex constants) **and** an ADR-019 amendment | The parity check hardcodes per-platform model allowlist regexes; drift between the documented policy and the enforcement regex causes false CI failures (or, worse, silently accepts disallowed models) |
| A new immutable constraint or domain rule | New file under `.context/rules/<file>.md` and link from `.context/rules/README.md` | Rules live in one directory by convention |
| A canonical prompt under `.github/prompts/*.md` that is duplicated as inline prompt text inside a workflow file (e.g., `pr-resolve-all.md` is mirrored in `agent-fix-reviews.yml` and `agent-relay-reviews.yml`) | Every inline mirror in the same PR | Prompt-file edits without inline-mirror updates have already caused real regressions (PR #95 → #96 → #97 phase-ordering bug) |
| Add a pipeline label to `docs/guides/agent-pipeline.md`'s label table | `scripts/setup.sh` `_ensure_label` list (and the fallback warning's manual-label list in the same script) | Labels documented but not auto-created cause silent setup drift |
| Add, remove, rename, or move a file that the repo-structure inventories enumerate (top-level files, `.context/**`, or `docs/**`) | The owning inventory module: `scripts/checks/010-required-files.sh` for top-level files, `scripts/checks/015-context-pack.sh` for `.context/**`, `scripts/checks/030-docs-structure.sh` for `docs/**`; **and** any human index / README that lists the file; **and** `install.sh` if the file ships from the dotfiles install | Repo-structure enforcement is split across inventory checks, human-facing indices, and bootstrap. `scripts/checks/030-docs-structure.sh` only covers the `docs/**` inventory; it is not the whole gate |
| Change live-state storage location, `agent-state:v1` comment schema, label set, or session-summary cadence | `.context/state/README.md`, `.context/sessions/README.md`, `.context/state/agent_state_comment_template.md`, `AI_REPO_GUIDE.md`, and `docs/guides/multi-agent-coordination.md` | ADR-025 splits live coordination (GitHub comments/labels) from durable in-tree lessons; drift between these surfaces breaks onboarding and handoff |
| Rename or restructure a section heading in `AGENTS.md` | The "Read first" / "Role selection" references in `CLAUDE.md` and `.github/copilot-instructions.md` (verify each cited heading still resolves) **and** bump `AGENTS_MD_VERSION` + the handshake token in the same PR | Pointer files cite AGENTS.md headings verbatim; silent drift breaks the pointer pattern (#207, #208) |
| Rename or move any `.context/rules/process_*.md` file (or restructure a section heading inside one) | The link table in `AGENTS.md` (verify each row still resolves to the renamed/moved file) **and** the section-anchor redirect table in `AGENTS.md` (update the right-hand-side path) **and** the "Read first" / "Role selection" pointer references in `CLAUDE.md`, `.github/copilot-instructions.md`, and `AI_REPO_GUIDE.md` (these now link directly to specific `process_*.md` files) **and** any cross-file references inside other `.context/rules/process_*.md` files **and** any ADR or guide that cites the file or section by path/anchor | The thin AGENTS.md links into per-concern files by file path (and the redirect table maps legacy section anchors to new file paths); pointer files now also link directly to specific process files; silent drift breaks the link table, strands the redirect entries, or breaks the pointer files (#207, #208) |
| Add or change a workflow-trigger row in `docs/guides/agent-pipeline.md` § "Workflow verifiability matrix" | `scripts/verify-pr.sh` detection rules (the matrix is the source of truth; the script is the enforcement) **and** `scripts/tests/verify-pr.bats` fixture cases covering the new bucket **and** `.github/PLAN_TEMPLATE.md` if the `Change class` enum needs a new value **and** `docs/guides/sandbox-verification.md` if the new trigger requires sandbox verification | The matrix, classifier, plan field, and playbook are co-load-bearing for ADR-016; drift between them is the failure mode the gate exists to prevent (issue #227, PR #225) |
| Add, remove, rename, or re-designate a `P<n>` / `AP<n>` entry in `.context/rules/repo_orchestration_patterns.md` (including changing a block-vs-advisory designation) | The `Review guidelines` link in `AGENTS.md` if a referenced ID disappears, **and** the role-step lists in `.agents/critic.md` and `.agents/judge.md` (canonical) — the platform overlays inherit automatically since they only point at the canonical — if the entry's review responsibility shifts, **and** an ADR amending ADR-020 if a block condition changes (block conditions are a Critic/Judge contract — content edits do not require an ADR, designation/contract edits do) | Pattern citations are part of a Critic/Judge contract; silent renames break review-time citations and let designation drift go unnoticed |

## Soft rule

If you find yourself repeatedly writing
`<companion-file>: no changes required` for the same change shape, the
trigger table is wrong — propose a row change in a separate PR rather
than papering over it.

## How to declare "no changes required"

Add a line to your PR description like:

```text
AI_REPO_GUIDE.md: no changes required (only edited a single ADR; layout
and commands unchanged)
```

Judge accepts this as satisfying the trigger; Critic may still flag it if
the justification looks weak.
