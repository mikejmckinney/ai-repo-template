# ADR-022: Top-level markdown scope split (README / AI_REPO_GUIDE / AGENTS)

## Status

Accepted

## Date

2026-05-08

## Context

Five markdown files live at the repo root:

- `README.md` — human onboarding and GitHub landing page
- `AI_REPO_GUIDE.md` — token-optimized agent reference
- `AGENTS.md` — thin contract + link table to per-concern process rules (post-ADR-021)
- `CLAUDE.md` — Claude Code native memory pointer to `AGENTS.md` (ADR-002)
- `AGENT.md` — deprecated redirect kept for back-compat

Two of these (`CLAUDE.md`, `AGENT.md`) are intentional pointer-facades. The README / AI_REPO_GUIDE / AGENTS triangle is where overlap accumulates: each round of template evolution tends to add the same fact to two or three of them, then drift causes the copies to diverge.

ADR-021 reshaped `AGENTS.md` (335 lines → 96 lines), shifting most process content into `.context/rules/process_*.md`. Without revalidating the README ↔ AI_REPO_GUIDE boundary, both files would continue to grow, duplicating both each other and the new rule files. Issue #254 made the audit explicit.

ADR-002 already assigned `AGENTS.md` ownership to Architect and called the README/AI_REPO_GUIDE/pointer split a "negative consequence" worth re-examining once `AGENTS.md` was decomposed. ADR-021 is that decomposition; this ADR is that re-examination.

## Decision

The three top-level files have **non-overlapping audiences** and **non-overlapping content**:

| File | Audience | Content | Link to others |
|---|---|---|---|
| `README.md` | First-time human contributors and the GitHub landing page | What the template is, why use it, how to install, top-level repo map (~11 rows), 3 setup options, verification, customization, limitations, future improvements, FAQ. Stays renderable on github.com. | Links *out* to `AI_REPO_GUIDE.md` for the full directory tree, agent-file catalog, workflow catalog, and onboarding prompts. Links to `AGENTS.md` only as "agents read this first." |
| `AI_REPO_GUIDE.md` | AI agents doing onboarding or needing a structured reference | Full ASCII directory tree, key files by purpose (agent instructions, context pack, prompts, scripts, issue templates, deployment configs, dev tools, CI/CD workflows), conventions, verification commands, onboarding prompts (first-time init + per-session). | Links to `AGENTS.md` for truth hierarchy and per-concern rules; defers to `.context/rules/**` for canonical process. |
| `AGENTS.md` | All AI tools (auto-loaded from repo root) | Thin contract: handshake, truth hierarchy, link table to `.context/rules/process_*.md`, anchor-redirect table for legacy citations. ≤100 lines. | Links to `AI_REPO_GUIDE.md` and `.context/00_INDEX.md` for project overview; links to `.context/rules/process_*.md` for everything procedural. |

**Decision rule for new content:** if a fact is for *humans*, it goes in `README.md`. If a fact is for *agents but is structural reference* (where a file lives, what command verifies what), it goes in `AI_REPO_GUIDE.md`. If a fact is *binding process* (a rule every role must follow), it goes in `.context/rules/process_*.md` and `AGENTS.md`'s link table is updated.

The five-file shape is preserved. No file is deleted. No file is merged into another. Pointer files (`CLAUDE.md`, `AGENT.md`) keep their current minimal facade role.

## Audit table

Snapshot of the duplication that existed before this ADR landed. "Canonical home" is where the content lives after this PR; "removed from" lists the files that previously duplicated it.

| Content | Canonical home (after) | Removed from (was duplicated in) | Why this home |
|---|---|---|---|
| Full ASCII directory tree (~120 lines) | `AI_REPO_GUIDE.md` § Repository Structure | `README.md` § Repository Structure | Agents need the structured tree; humans get the 12-row Repo map summary at the top of README and a link to the full tree |
| `AI Agent Files` table (15 rows of `.agent.md` files + tool-specific paths) | `AI_REPO_GUIDE.md` § Key Files by Purpose → Agent Instructions | `README.md` § AI Agent Files | Tool-loader detail is agent reference, not human onboarding |
| `Context Pack` table (LLM memory file catalog) | `AI_REPO_GUIDE.md` § Key Files by Purpose → Context Pack | `README.md` § Context Pack | Agents consult this when locating rule files; humans don't author `.context/**` directly |
| `Prompts` table | `AI_REPO_GUIDE.md` § Key Files by Purpose → Prompts | `README.md` § Prompts | Agent dispatch surface |
| `Issue Templates` table | `AI_REPO_GUIDE.md` § Key Files by Purpose → Issue Templates | `README.md` § Issue Templates | Reference detail |
| `Deployment Configs` table | `AI_REPO_GUIDE.md` § Key Files by Purpose → Deployment Configs | `README.md` § Deployment Configs | Reference detail; README keeps a one-line link |
| `Development Tools` table (pre-commit, ADRs, postmortems, guides, scripts) | `AI_REPO_GUIDE.md` § Key Files by Purpose → Development Tools | `README.md` § Development Tools | Reference detail |
| `CI/CD Workflows` table (~17 rows) | `AI_REPO_GUIDE.md` § Key Files by Purpose → CI/CD Workflows | `README.md` § CI/CD Workflows | Workflow catalog is a reference surface, not onboarding |
| First-Time Repo Initialization prompt block | `AI_REPO_GUIDE.md` § Onboarding Prompts → First-time repo initialization | `README.md` § First-Time Repo Initialization | Agent-consumed prompt; README links to it |
| Onboarding New Agent Sessions prompt block | `AI_REPO_GUIDE.md` § Onboarding Prompts → New agent session | `README.md` § Onboarding New Agent Sessions | Same |
| `Best Practices` (when using template) | `README.md` (kept, slimmed) | — | Human-facing template-customization tips |
| Repo map summary (audience-oriented) | `README.md` § Repo map | — | Already audience-oriented; complements the AI_REPO_GUIDE tree |
| Setup (3 options) | `README.md` § Setup | — | Human-facing |
| Limitations / Future Improvements / FAQ | `README.md` | — | Required by `test.sh`; human-facing |

**Net effect:**

```
README.md         475 →  222 lines  (remove agent-facing reference tables)
AI_REPO_GUIDE.md  376 →  419 lines  (absorb the two onboarding prompt blocks)
AGENTS.md          96 →   96 lines  (untouched)
```

Measured with `wc -l` before/after; recorded in the PR description.

## Options Considered

### Option 1: Tighten boundaries in place (chosen)

- **Pros**: Preserves the five-file shape, which is intentional and tool-loaded (Codespaces Dotfiles, Claude Code memory loader, Copilot auto-load, GitHub repo landing page). Most files lose content rather than gain it. No behavioral changes to scripts or workflows.
- **Cons**: Requires authors of future template additions to remember the decision rule. Mitigated by this ADR being grep-discoverable from any of the three files.

### Option 2: Merge `AI_REPO_GUIDE.md` into `README.md`

- **Pros**: One fewer file at the root.
- **Cons**: They serve different audiences (humans vs. agents). The fact that they overlap doesn't mean they should merge — it means the overlap should consolidate. Merging them would force humans to scroll past agent-facing reference tables and force agents to parse human onboarding prose.

### Option 3: Amend ADR-002 instead of writing a new ADR

- **Pros**: Lower ceremony.
- **Cons**: ADR-002 is narrowly scoped to *who owns AGENTS.md*. The README/AI_REPO_GUIDE scope split is a different decision (which content lives where), affecting two files ADR-002 doesn't change. A new ADR captures the scope-split rationale cleanly without bloating ADR-002.

### Option 4: Skip the audit

- **Pros**: Zero work.
- **Cons**: Continued drift. The pre-#264 README already had ~250 lines of content that duplicates AI_REPO_GUIDE; without an explicit decision rule, every future template addition compounds the problem.

## Consequences

### Positive

- **Faster onboarding for both audiences.** Humans land on a ~210-line README that explains what the template is and how to use it. Agents reading `AI_REPO_GUIDE.md` get the structured map without re-reading what `AGENTS.md` already covered.
- **Cheaper future maintenance.** New facts have one canonical home. Doc-sync triggers in `.context/rules/process_doc_maintenance.md` can target the canonical file directly rather than fanning out to three.
- **Drift detection is mechanical.** The audit table makes it obvious if a future PR re-introduces duplication: any content matching a row in the table belongs in the canonical home.

### Negative

- **One-time churn.** This PR rewrites large chunks of README and adds two sections to `AI_REPO_GUIDE.md`. Reviewers must verify no content is silently lost (the audit table is the receipt).
- **External links to README sections may break.** The biggest risk is documentation outside this repo linking to `README.md#repository-structure` or similar removed anchors. README keeps the most-cited section anchors stable (Setup, Limitations, Future Improvements, FAQ, License) and gains new anchors (Repo map) that are also stable.

### Neutral

- **`AGENTS.md` is untouched** by this PR. ADR-021 already brought it to its target shape.
- **Pointer files (`CLAUDE.md`, `AGENT.md`) are untouched.** ADR-002's pointer/target ownership split is preserved as intentional.
- **`test.sh` is untouched.** All five files still exist; the test's REQUIRED_FILES check is unaffected. The README `## Limitations`, `## Future Improvements`, and `## FAQ` checks still pass — those sections are kept.

## Implementation

- [x] Author this ADR with the audit table embedded.
- [x] Trim `README.md`: remove the full directory tree, the seven reference tables (AI Agent Files, Context Pack, Prompts, Issue Templates, Deployment Configs, Development Tools, CI/CD Workflows), and the two onboarding prompt blocks. Replace each with a one-line link to `AI_REPO_GUIDE.md`.
- [x] Extend `AI_REPO_GUIDE.md`: add a new "Onboarding Prompts" section containing the two prompt blocks moved out of README.
- [x] Update `docs/decisions/adr-002-agents-md-ownership.md` Status line to note this ADR also extends it.
- [x] Update `docs/decisions/README.md` index with the ADR-022 row.
- [x] Run `bash test.sh` — expect green.
- [x] Record before/after `wc -l` in the PR description.

## References

- ADR-002 — original AGENTS.md ownership decision; this ADR resolves the "pointer/target ownership split" follow-up flagged in its Negative Consequences.
- ADR-021 — AGENTS.md decomposition that made this audit possible.
- Issue #254 — parent feature request.
- Issue #251 — Phase 5 epic that #254 closes part of.
