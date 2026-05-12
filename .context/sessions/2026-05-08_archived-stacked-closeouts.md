<!-- TEMPLATE_PLACEHOLDER: In a real project, this file captures the most recent session's outcomes. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->

# Latest Session Summary

> **Purpose**: Capture what happened in the most recent session, especially decisions and lessons learned. This prevents repeating mistakes and enables cognitive handoff.
>
> **Historical note**: This archive predates ADR-025. For current task progress, see the assigned issue/PR and latest `agent-state:v1` comment; legacy `.context/state/_active.md` / `task_*.md` references may be stale.

## Session Info

**Date**: 2026-05-04
**Duration**: ~2h
**Agent/Developer**: GitHub Copilot (interactive session)

---

## Close-out: pr-252-orchestration-patterns — 2026-05-08 (in progress — PR #259 open, awaiting human merge)

**What shipped**: Sub-issue #252 of epic #251 (binding rules reference for orchestration anti-patterns). New `.context/rules/repo_orchestration_patterns.md` (~345 lines, P1–P8 patterns + AP1–AP8 anti-patterns with detection signals, remediation, block conditions; AP3/AP4/AP6/P7 generalized from PM-001/-002/-003) and ADR-020 ratifying the file's binding placement and block-vs-advisory designations. Wired into review entrypoints: AGENTS.md "Review guidelines"; critic.agent.md and judge.agent.md (both registries) step-3 grounding with severity mapping (MAJOR/CRAFT for Critic; AP4/AP5/AP8 per-entry block triggers enumerated in mirror-symmetric detail across `.github/agents/` and `.claude/agents/`); `.context/rules/agent_ownership.md` ownership row; `process_doc_maintenance.md` trigger row; `test.sh` CONTEXT_FILES; `install.sh` MULTIAGENT_FILES; `AI_REPO_GUIDE.md` rules tree + Context Pack table. AGENTS_MD_VERSION 9→10. test.sh: 335 passed (was 334). pr-resolve-all loop ran 13 rounds under `cap-override` label; converged after R12+R13 produced no new feedback. 35 total findings; 30 fixed; 5 deferred (with rationales on threads). 25 commits on `feature/architect-252-orchestration-patterns-reference`.
**What was harder than expected**: Dual-registry drift hit three separate times. R7 added AP4/AP5/AP8 enumerated triggers to `.claude/agents/judge.md`; R10 then required syncing the same enumeration back to the canonical `.github/agents/judge.agent.md`. ADR-003's parity contract is `description:`-byte-only, but reviewers (correctly) expect symmetric body detail too. Also: Codex repeatedly flagged the coordination.md / _active.md lock value as ambiguous between issue # and PR # — defended the convention (lock created at branch time, before PR exists), but the underlying ambiguity is real and worth a schema fix; filed as #260 under epic #251.
**What generalizes**: (1) When mirroring role file detail across `.github/agents/` and `.claude/agents/`, treat the body-detail symmetry as a soft contract — diverging detail levels will get flagged even though `test.sh` doesn't enforce it. Worth adding a body-length-parity smoke test? (2) The Citation convention for "anchor-stable references like `AGENTS.md:3`" is only credible if the file actually applies it — R10-02 was Gemini noticing the convention was self-undermining. Document conventions only when the document itself uses them. (3) Lock identifiers in `coordination.md` carry implicit meaning (sometimes issue #, sometimes PR #, sometimes branch) — schema work tracked in #260.

---

## Close-out: pr-220-phase2 — 2026-05-07 (in progress — PR #250 open, awaiting human merge)

**What shipped**: Phase 2 of issue #220 (per-role model tiering across Claude Code and Copilot). New `docs/decisions/adr-019-per-role-model-tiering.md` (ADR-019, NOT ADR-016 — collision with the pre-existing Pre-merge verification gate ADR; documented inline + in numbering correction comment 4393550797). 7 amendments (version pinning, per-platform fallback strategy, A/B framework deferred to Phase 4, placeholder tolerance, dev-context exception, Copilot cost-tier ceiling, qualified vendor format). Tier table: High (analyst/architect/judge) → `claude-opus-4-7` / `'Claude Opus 4.7 (copilot)'`; Mid (critic/pm/backend/frontend/devops) → `claude-sonnet-4-6` / `'Claude Sonnet 4.6 (copilot)'`; Low (qa/docs) → `inherit` / omitted. All 20 agent files updated; ADR-003 Status updated to "(per-role `model:` choice superseded by ADR-019)". AGENTS.md gained a "Model tier dispatch convention" section; `.github/PLAN_TEMPLATE.md` gained a `### Model tier` field; `docs/guides/agent-pipeline.md` cost section refreshed. `test.sh` Check C (per-platform allowlists) added — 334 pass / 0 fail. v1 ships single-string pins (no fallback arrays) for safety; fallback array shape is documented for follow-up. cap-override loop converged after round 1 (3 substantive Copilot findings — all stale `ADR-016` refs caught by the renumbering — fixed in commit 5fa43b3) plus 2 clean iterations (no new bot feedback). Gemini was rate-limited the entire run.
**What was harder than expected**: ADR numbering collision. The plans throughout #220 said "ADR-016", but ADR-016 had landed on a different decision (Pre-merge verification gate, accepted 2026-04-26) before Phase 2 implementation began. Renumbering to ADR-019 had to happen *before* any code edits referenced the new number, and the Copilot reviewer caught three stale `ADR-016` references in state files that the renumbering pass had missed.
**What generalizes**: When carrying a planned ADR number across multiple sessions, re-verify the next-available number at implementation time — don't trust planning-time numbering. A single grep for `ADR-NNN\|adr-NNN` across all changed files (state, locks, plans, body text) is the cheap verification that catches the renumbering misses before bot review does. Add to plan template / pre-push checklist? Worth considering as a follow-up.

---

## Close-out: phase3-issue-229 — 2026-05-06 (in progress — PR #244 open, awaiting human merge)

**What shipped**: Phase 3 of issue #229 (pre-push Critic prompt). New `.github/prompts/pre-push-review.md` (4-step prompt: diff scope → Critic dispatch → lint → tests, with single-Markdown summary). Wired in as SHOULD on AGENTS.md → "Work style" with a precise definition of "non-trivial" (>50 LOC OR scripts/*.sh, .github/workflows/*.yml, role files, AGENTS.md/CLAUDE.md/copilot-instructions.md), and as a MUST on `devops.agent.md` for shell/workflow changes. critic.agent.md gained an "Invocation surfaces" subsection (PLAN-GATE / DIFF-GATE / PRE-PUSH). Index entries added to prompts/README.md, agent-best-practices.md, AI_REPO_GUIDE.md Verification Commands. test.sh: 6 new invariants + REQUIRED_FILES entry → 285 passed (was 278). Bot loop converged after 5 rounds (6→1→2→0→0 findings, all 9 threads resolved). 7 commits on `feature/devops-229-phase3-v2`. NO git pre-push hook (deferred per ADR-013 friction concerns) — manual prompt only.
**What was harder than expected**: (1) ISS-07 in Round 2 caught my own Round 1 ISS-06 fix as an active footgun — I'd added `bash .github/prompts/pre-push-review.md` as a "manual runner" example, but bash on a Markdown file would error on `---` frontmatter and execute backticks in prose. Replaced with `cat` preview + `@<agent> follow` invocation instructions. Lesson: prompts are read by agents, not executed by bash — never document them as shell-runnable. (2) ISS-09 in Round 3 caught an internal contradiction this very PR introduced: AGENTS.md "Work style" defined non-trivial one way, the prompt's "When to skip" block defined it another way. Two surfaces with two definitions invites implementers to skip on the very class of change (governance docs) that most warrants the review. Aligned the skip rule verbatim with AGENTS.md.
**What generalizes**: When a change introduces a new policy-trigger threshold across multiple files, name it once and reference it everywhere — don't restate it. Future PRs that touch one definition without the other will reintroduce the same drift. Worth filing an ADR addendum or rule note if this pattern recurs.

---

## Close-out: phase4-issue-229 — 2026-05-05 (in progress — PR #241 open, awaiting review)

**What shipped**: Phase 4 of issue #229 (ADR-017 + cap-override justification rule). Components: (1) `docs/decisions/adr-017-template-repo-pre-commit-default.md` — installs pre-commit shellcheck + actionlint for the *template repo only*, with explicit "Non-reversal of ADR-013" subsection (ADR-013 governs derived repos and stays Accepted, no supersession). (2) `.pre-commit-config.yaml` (new at repo root) — minimal config: shellcheck-precommit v0.10.0 + rhysd/actionlint v1.7.7, hook flags pinned to match `.github/workflows/lint-and-format.yml`. `.pre-commit-config.yaml.template` preserved verbatim with a top-of-file comment cross-linking ADR-017 so the two-track design is legible. (3) `cap-override` justification rule in `.github/prompts/pr-resolve-all.md` Round disciplines section: when override is active and round count > 3, every Resolution Report from round 4 onward must include a literal `Override justification: <category>` line (`sandbox-class | legitimate refactor | complex semantic dependency | other: <reason>`). Resolution Report template updated. Judge gate item 15 added enforcing BLOCK at diff-gate; mirrored to `.cursor/BUGBOT.md` and `.gemini/styleguide.md` (each bumped from "eight gates" → "nine gates"). `docs/guides/agent-pipeline.md` updated in two places (Repository variables row + Manual Intervention Points table). `test.sh`: 12 new invariants (ADR-017 Status, ADR-013 non-supersession guard, decisions README index, pre-commit-config existence + shellcheck/actionlint hooks, template cross-link, pr-resolve-all override rule, judge gate item, BUGBOT/styleguide mirrors). 278 passing (0 failed).
**What was harder than expected**: Choosing the line position for the `Override justification:` field in the Resolution Report template required care — placing it under `### Summary` (before the per-item table) is the only spot where a regex-based diff-gate check can locate it deterministically without parsing markdown structure.
**What generalizes**: When a new policy gate is added that bot reviewers should also enforce inline, the alignment pattern from PR #235 (canonical Judge item N + mirror entries in BUGBOT.md and styleguide.md + update the "N gates" count line) is the template. The "N gates" sentence in both reviewer files is load-bearing context for those LLMs and must be bumped in lockstep.

---

## Close-out: phase1.5-issue-229 — 2026-05-09 (in progress — PR not yet merged)

**What shipped**: Phase 1.5 of issue #229 (runtime-semantics gate). Three components: (1) `scripts/lint-shell-conventions.sh` — RULE-01 (`grep -c` without `|| true` in `set -e` scripts) + RULE-02 (unanchored `grep -E` alternation patterns); wired into `lint-and-format.yml`. (2) `scripts/lib/jq/relay-cycle-count.jq` extracted from `agent-relay-reviews.yml` with 3 fixture pairs and `scripts/test-jq-filters.sh` auto-discovery runner. (3) `scripts/test-verify-env.sh` — 4 fixture cases covering `_PLACEHOLDER_EXCLUDE` `$`-anchor logic. Also: RULE-01 true-positive found+fixed in `test-parallelism-report-parser.sh:271`. Diff-coupling gate added to `judge.agent.md` item 14 + mirrored into BUGBOT.md + styleguide.md. `test.sh` 266 passing (0 failed).
**What was harder than expected**: RULE-02 cannot cover variable-expanded `grep -E "$VAR"` patterns statically — only literal-quoted strings. The actual PR #228 bug was in the variable definition, not the grep call. RULE-02 catches the forward-looking class of future literal-pattern mistakes.
**What generalizes**: When adding rules that shellcheck cannot cover, pair them with fixture tests immediately (the diff-coupling gate now enforces this for future contributors). The `|| true` pattern inside `$(...)` is semantics-safe: `grep -c` always writes a number to stdout before its exit code; `|| true` only suppresses the non-zero exit propagation, so the captured value is always correct.

## Close-out: pr-238-bot-review-loop — 2026-05-05 (COMPLETE — R19+R20 clean)

**What shipped**: Rounds 14–16 of pr-resolve-all.md on PR #238. Fixed ISS-38 (mandatory | in dquote RULE-02), ISS-39 (lone backslash not valid anchor), ISS-41 (inline comment # set -e false positive), ISS-42 (set -o pipefail re-introduced by ISS-34), ISS-43 (jq stderr capture), ISS-44/48/51 (&&-guard: added then partially reverted due to &&-in-pattern FN), ISS-45/52 (Pass B added then dropped — same $-var exclusion blindspot as ISS-30), ISS-46 (mktemp template), ISS-47 (shebang -e detection), ISS-50 (positional params in Pass B). CI: ✅ green (268/0). 7 commits pushed on feature/devops-229-phase1.5.
**What was harder than expected**: (1) CLAUDE_PAT not available in Cursor Cloud Agent VM (added to Cursor dashboard mid-session; takes effect in next VM). Blocked posting Phase 3 resolution reports and Phase 4 thread resolution. (2) ISS-44 && guard: real bash semantics are complex — grep-c && cmd is safe but cmd && grep-c fires set -e; && inside quoted string fools line-level grep; reverted to conservative approach. (3) ISS-45 Pass B: adding a second pass to catch $-mid-pattern cases introduced the same $-var-exclusion blindspot on pass B. Dropped in favor of documenting the limitation.
**What generalizes**: (1) CLAUDE_PAT must be added as a Cursor Cloud Agent secret (Cursor Dashboard → Cloud Agents → Secrets) — the cursor[bot] App token has contents:write but not pull-requests:write or issues:write. (2) Line-level grep cannot distinguish a pattern argument from subsequent file arguments in a grep command — the ISS-30 [^"$]* approach has a known blind spot for $ anchors mid-pattern; fix requires per-token parsing which is out of scope for this linter.

**COMPLETED**: CLAUDE_PAT obtained mid-session via user. All reports posted, all threads resolved/deferred. Stopping condition met (R19+R20 clean). PR #238 ready for merge.

**QUEUED PHASE 1 INDEX (Round 14, post as PR comment):**
Round 14 — 25 threads triaged: ISS-38 (dquote mandatory |, ✅ Fixed), ISS-39 (lone \ not anchor, ✅ Fixed), ISS-40 (\\$ false-neg, ❌ Not reproducible), ISS-41 (inline # set-e FP, ✅ Fixed), ISS-42 (pipefail regression, ✅ Fixed), ISS-43 (jq stderr, nit ✅ Fixed), ISS-07↩ (per-branch anchor, ❌ Out of scope ×3), ISS-30↩ (already resolved ×6), ISS-22↩ (already resolved ×2), ISS-24↩ (already resolved), ISS-34↩, ISS-35↩, ISS-37↩, ISS-31↩ (all ❌ deferred/OOS).
Round 15 — 4 new: ISS-44 (&&guard, ✅ Fixed then reverted→ISS-51), ISS-45 (dquote $ anchor, partially fixed→dropped), ISS-46 (mktemp template, nit ✅ Fixed), ISS-47 (shebang -e, ✅ Fixed), ISS-49 (test.sh sed fragile, ❌ OOS).
Round 16 — 4 new: ISS-48 (&&guard restricted, ✅ Fixed), ISS-50 (positional params, ✅ Fixed), ISS-51 (&&-in-quotes FN, ✅ Fixed by revering ISS-44), ISS-52 (Pass B $ blind spot, ✅ Fixed by dropping Pass B), ISS-53 (set -e on linter, ❌ OOS = ISS-31), ISS-54 (per-quoted-string anchor, ❌ OOS = ISS-07).

**ELIGIBLE BOT THREADS FOR PHASE 4 RESOLUTION (post audit reply + resolveReviewThread):**
All threads where Phase 2 = ✅ Fixed and author is allow-listed bot:
- PRRT_kwDOQ1tpTM5_qCNJ (chatgpt, ISS-38, fixed in 8eed29c)
- PRRT_kwDOQ1tpTM5_puFb (gemini, ISS-39, fixed in 8eed29c)
- PRRT_kwDOQ1tpTM5_qG94 (gemini, ISS-41, fixed in 8eed29c)
- PRRT_kwDOQ1tpTM5_qH32 (cursor, ISS-42, fixed in 8eed29c)
- PRRT_kwDOQ1tpTM5_puFv (gemini, ISS-43, fixed in c898d50)
- PRRT_kwDOQ1tpTM5_pY9o (chatgpt, ISS-44→already fixed earlier, ISS-24)
- PRRT_kwDOQ1tpTM5_pYsY (gemini, ISS-46+ISS-47, fixed in a6d614d)
- PRRT_kwDOQ1tpTM5_quRD (gemini, ISS-46, fixed in a6d614d)
- PRRT_kwDOQ1tpTM5_quRI (gemini, ISS-47, fixed in a6d614d)
- PRRT_kwDOQ1tpTM5_quQk (gemini, ISS-48, reverted — leave open)
- PRRT_kwDOQ1tpTM5_quQ6 (gemini, ISS-45/52 dropped — leave open as OOS)
- PRRT_kwDOQ1tpTM5_rAWJ (gemini, ISS-50, fixed in debca1e)
- PRRT_kwDOQ1tpTM5_rAXD (gemini, ISS-48/51, fixed in d48381b)
- PRRT_kwDOQ1tpTM5_rZLP (gemini, ISS-51, fixed in d48381b — && reverted)
- PRRT_kwDOQ1tpTM5_rZLR (gemini, ISS-52, dropped — leave open as OOS)
- PRRT_kwDOQ1tpTM5_rZLW (gemini, ISS-53 = ISS-31 deferred — leave open)
- PRRT_kwDOQ1tpTM5_rZL0 (gemini, ISS-54 = ISS-07 deferred — leave open)
Remaining already-resolved/OOS threads: leave open for human ack per pr-resolve-all.md Safety rules.

---

## Close-out: pr-235-merged — 2026-05-04

**What shipped**: PR #235 (`feat(#229-phase2): behavioral rules + external-reviewer gate alignment`) merged (990942c). Bot-review loop ran 19+ rounds across two sessions. Fixes included: Rule 3 reference name alignment; BUGBOT.md non-existent CONTRIBUTING.md removal; procedural-prompt exemption expansion to full canonical list; NN-*.md Pre-Flight trigger added; `REQUEST_CHANGES` removed from Medium Priority mapping; plan gates upgraded from Medium→High Priority in both BUGBOT.md and styleguide.md. PR body doc-sync checklist corrected. Merge conflict in `_active.md` (PR #234 vs #235 parallel writes) resolved by merge commit (896f48e).
**What was harder than expected**: Missing `/gemini review` triggers after each push — caused two "clean" rounds (R14/R15) to be invalid (silence ≠ no-review). Required re-running R16/R17 explicitly. GPG rebase rebasing failed (`Author is invalid`); worked around by using `git merge` + conflict resolution commit instead of `git rebase`.
**What generalizes**: (1) Always post `/gemini review` after each push and `sleep 420` before scanning — silence without the trigger means bot hasn't re-reviewed. (2) The single-writer `_active.md` schema causes merge conflicts under ADR-009 parallel multi-agent execution. Issue #237 filed to adopt multi-section schema.

---

## Close-out: pr-232-review-round4 — 2026-05-04

**What shipped**: Addressed 4 open threads (ISS-20 through ISS-23) on PR #232 via pr-resolve-all.md. Fixes: ISS-23 (chatgpt P1) — `page_had_in_window` early-exit in `fetcher.py` was keyed on `closedAt` but the query orders by `UPDATED_AT DESC`; old PRs bumped by recent comments occupy early pages while recently-merged PRs (no post-merge activity) sit on later pages, causing silent undercounting. Fixed by adding `updatedAt` to `PR_QUERY` and replacing the `closedAt`-based break with `nodes[-1]['updatedAt'] < since` — a monotone safe bound on the ordering field (commit `2e9f691`). Deferred: ISS-20 (`✅ Already resolved` — old `--paginate --jq` approach replaced by `fetcher.py`); ISS-21 (date fallback already script-blocking via `set -euo pipefail`); ISS-22 (`AGENT_RE` too broad — `isBot` addition is out of scope). Phase 4 attempted: PRRT_ thread IDs not returned by MCP `get_review_comments`; ISS-23 thread audit reply posted at `discussion_r3181831110` but `resolveReviewThread` not attempted. CI: pending on `2e9f691`.
**What was harder than expected**: Phase 4 thread resolution blocked by MCP API gap — `get_review_comments` does not return PRRT_ node IDs required by `resolveReviewThread`.
**What generalizes**: The UPDATED_AT vs closedAt ordering trap: when paginating by `UPDATED_AT DESC` and filtering by `closedAt >= since`, the only safe early-exit criterion is `updatedAt < since` (not `closedAt < since`), because `updatedAt >= closedAt` always holds. A page full of old-commented PRs has no `closedAt`-in-window entries but can precede pages with recently-merged PRs. Pattern: early-exit on the ordering field, not the filter field.

---

## Close-out: pr-232-review-round3 — 2026-05-04

**What shipped**: Addressed 2 new chatgpt-codex-connector findings (Round 3) on PR #232. Fixes: (1) ISS-18 — `test.sh` linter invariants changed from bare tool name greps (which match comments) to flag-specific patterns `shellcheck --severity`, `shfmt -d`, and `xargs -r -0 actionlint` — all unique to `run:` blocks; a removed step no longer passes the guard if comments remain; (2) ISS-19 — actionlint step in `lint-and-format.yml` switched from static `*.yml` glob to `find -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) -print0 | xargs -r -0 actionlint` (consistent with shellcheck/shfmt pattern; covers both extensions; `-r` handles no-match gracefully). CI: ✅ green on `cf15481`. Both threads resolved. Default round cap (3/3) reached.
**What was harder than expected**: None — both were straightforward substitutions.
**What generalizes**: When writing test invariants that verify a tool is wired in a config file, match the tool's CLI flags (unique to the `run:` block) rather than the bare tool name (which also appears in comments). Pattern: `grep -qE 'tool --flag'` over `grep -q 'tool'`.

---

## Close-out: pr-232-review-round2 — 2026-05-04

**What shipped**: Addressed 3 new chatgpt-codex-connector findings (Round 2) on PR #232. Fixes: (1) ISS-16 — removed `|| PR_JSON="[]"` fail-silent fallback; `set -euo pipefail` propagates errors and `jq -s '.'` naturally emits `[]` for empty streams; (2) ISS-17 — changed `[:\s]+` to `[*:\s]+` in `FIXED_RE`/`TOTAL_RE` for both `pr-iteration-stats.sh` and `test-pr-iteration-stats.sh`; bold metric labels `- **Fixed in this pass**: X` from pr-resolve-all.md Phase 3 template now parse correctly; added `REPORT_FIX_BOLD` fixture and Test 11. ISS-15 (first:100 cap) deferred — same as ISS-05/12 Round 1. CI: ✅ green on d5eb5f4. 2 threads resolved, 1 deferred with reply.
**What was harder than expected**: None — straightforward regex fix once the bold format mismatch was identified.
**What generalizes**: When capturing output with regex, use `[*:\s]+` instead of `[:\s]+` for label separators if the source can emit either plain `Label: N` or markdown-bold `**Label**: N` format. Always fixture-test both variants.

---

## Close-out: pr-232-review-round1 — 2026-05-04

**What shipped**: Addressed 14 bot review findings (chatgpt×2, Copilot×8, Gemini×3, CI×1) from PR #232 via pr-resolve-all.md. Fixes: (1) actionlint SC2038 — changed `find -print | xargs -r` to `-print0 | xargs -r -0` in lint-and-format.yml; (2) Added `.actionlint.yaml` + inline `-ignore` flags to suppress SC2016/SC2086/SC2129/SC2153/SC2018/SC2019 (pre-existing false positives); (3) Fixed GraphQL pagination cursor `$cursor` → `$endCursor`; (4) Fixed `--paginate + --jq "[...]"` multi-page JSON concatenation via NDJSON output + external `jq -s '.'`; (5) Fixed `REPORT_HEADER_RE` to match canonical `## Resolution Report` header (metric was counting zero rounds for all real PRs); (6) Fixed test fixtures + added Test 10 for canonical header; (7) Reduced lint-and-format.yml permissions to `contents: read`; (8) Fixed `_active.md` schema violations and bogus `parallel_validation` command. 9 bot threads resolved; 4 deferred with replies (first:100 cap, pagination perf, test dedup). CI: ✅ green.
**What was harder than expected**: actionlint's `.actionlint.yaml` `ignore-patterns:` config was silently not applied by the runner (config file not auto-discovered). Required passing `-ignore` flags inline as CLI args to the `actionlint` run step instead.
**What generalizes**: When a new linter is introduced that finds pre-existing violations, the CI will fail immediately. Plan for either (a) bulk-fixing pre-existing violations before enabling, or (b) adding inline suppressions for false-positives and filing follow-ups for real issues — then progressively tighten. For actionlint specifically: pass `-ignore` patterns inline via CLI rather than relying on `.actionlint.yaml` auto-discovery from the runner CWD.

---

## Close-out: pr-229-phase1 — in progress 2026-05-03

**What shipped**: Phase 1 of issue #229. Replaced `lint-and-format.yml` TEMPLATE_PLACEHOLDER with shellcheck (warning+, blocks) + shfmt (-d, blocks) + actionlint (blocks). Added `scripts/pr-iteration-stats.sh` — rolling 14-day PR review-loop metric with three counters (total_rounds, fix_rounds, rejected_rounds) plus thread counts, `--window`, and `--json` flags. Added `scripts/test-pr-iteration-stats.sh` with 19 smoke-test assertions. Ran shfmt auto-format on 14 pre-existing scripts. Added 8 new test.sh invariants. Updated `AI_REPO_GUIDE.md` with new script in table + verification commands.
**What was harder than expected**: `python3 - << 'PYEOF'` combined with stdin pipe fails under shellcheck (SC2259 — heredoc overrides pipe). Fixed by writing Python scripts to `mktemp -d` temp files and piping JSON to them separately.
**What generalizes**: SC2259 pattern: never combine `cmd | python3 - << 'HEREDOC'`. Always write inline Python to a temp file and call it as `python3 "$TMP_FILE"` when stdin data must be piped.



**What shipped**: Released stale locks for pr-216 and pr-179 in `coordination.md`; added missing `Result:` lines; refreshed `_active.md` to Issue #220 Phase 2 state; added missing close-out summaries for pr-179 and pr-216 to `latest_summary.md`; pre-registered `issue-220-phase2` lock template in PM Notes with `Paths` including `.github/agents/*.agent.md` and `adr-003` (kept out of Active Locks to avoid false stale-lock alerts before the branch exists).
**What was harder than expected**: Copilot relay (copilot-swe-agent) made an incorrect ISS-03 fix — removed `.github/agents/*.agent.md` from `_active.md` citing ADR-003, but live VS Code docs verify `.agent.md` supports `model:`. Required manual revert in `132452f`. The relay agent was operating on stale ADR knowledge.
**What generalizes**: When a relay agent cites an ADR as justification for a correction, verify the cited ADR is not itself under active revision. If a Phase 2 plan is in flight that supersedes an ADR, `_active.md` should reference the plan, not the soon-to-be-obsolete ADR. Add a note to agent-best-practices once a second instance appears.

## Backfilled History: pr-179 (fix/177-phase4-fallback-on-push) — merged 2026-04-25

**What shipped**: Phase 4 fallback parser in `agent-relay-reviews.yml`; graceful Copilot fallback when `CLAUDE_PAT` unavailable; ADR-008 updated to document new default behavior.
**What was harder than expected**: Testing the fallback path without triggering real credential failures; mock setup for the parser edge cases required careful scaffolding.
**What generalizes**: The primary-tool-fails → relay-via-alternate-credential pattern is reusable for any multi-credential agent workflow. Filed as a note in ADR-008 for now; no separate rule yet (N=1).

## Backfilled History: pr-216 (fix/206-pr-completion-criteria) — merged 2026-04-29

**What shipped**: PR completion criteria for interactive sessions codified in AGENTS.md §"PR completion criteria": stop condition (CI green + every bot thread resolved or deferred with comment + Resolution Report posted).
**What was harder than expected**: Nothing unexpected — straightforward docs/policy update.
**What generalizes**: The named convergence criterion pattern ("done when X, Y, Z are all true" rather than "done when it feels done") is broadly applicable to any iterative loop in agent workflows. Worth promoting to `agent-best-practices.md` once a second instance appears.

## What Was Accomplished

<!-- List concrete outcomes, not just "worked on X" -->

- **PR #225 / chore/coordination-cleanup** — released stale locks for pr-179 and pr-216 in `coordination.md`; added missing `Result:` lines and full lock blocks to Recent History; refreshed `_active.md` to Issue #220 Phase 2 state; backfilled missing `latest_summary.md` close-out entries for pr-179 and pr-216; pre-registered `issue-220-phase2` lock template in PM Notes with correct Paths and `State: backlog` (omitted from Active Locks to avoid false stale-lock alerts before branch exists).
- **Issue #224 closed** — the stale-lock alert that triggered this PR; root cause was lock blocks never moved to Recent History when PRs #179 and #216 merged.
- **5 bot-review rounds** — 15 total findings across gemini (11), chatgpt (3), and copilot (1); all resolved across commits `cbbf175` → `35eae6e` (copilot-swe-agent) → `132452f` → `5d52405` → `7a1e515` → `07b3de7`.

## Key Decisions Made

<!-- Document decisions AND their rationale -->

| Decision | Rationale |
|----------|-----------|
| `issue-220-phase2` lock `Session: feature/architect-220-phase2` | `TBD` breaks coordination automation (no branch match); expected implementation branch name used so on-open and on-close hooks fire correctly when Phase 2 work starts. |
| Lock state `planned` → `backlog` | No `task_issue-220-phase2.md` created in this PR; `backlog` is the accurate pre-dispatch state per Task States table. |
| ISS-03 revert of copilot-swe-agent fix | Agent removed `.github/agents/*.agent.md` from `_active.md` citing ADR-003; live VS Code docs verify `.agent.md` supports `model:` field — the ADR is superseded by Phase 2 plan. |

## What Didn't Work

<!-- IMPORTANT: This prevents the next session from repeating failed approaches -->

| Approach Tried | Why It Failed |
|----------------|---------------|
| `Session: chore/coordination-cleanup` on `issue-220-phase2` lock | Stale-lock workflow would fire false alert on PR #225 close — corrected to expected implementation branch. |
| `Session: TBD` on `issue-220-phase2` lock | Coordination automation keys off exact Session value; TBD matches nothing, causing duplicate missing-lock suggestions on future PRs. |

## Problems Encountered

<!-- Issues that came up and how they were resolved (or not) -->

- Copilot relay (copilot-swe-agent) incorrectly reverted ISS-03 by citing stale ADR-003. Required manual fix in commit `132452f`.

## Next Session Should

<!-- Specific, actionable recommendations -->

1. Start Issue #220 Phase 2 on branch `feature/architect-220-phase2`; create `task_issue-220-phase2.md` and move lock to `planned`
2. Address Issue #226 (state-file discipline): 4 sequenced PRs per plan comment #4364665611
3. Verify copilot-relay workflow failure (noted by user; deferred from this session)

## Environment Notes

<!-- Any setup issues, dependency problems, or environment quirks discovered -->

- Copilot relay workflow (`agent-relay-reviews.yml`) failing as of 2026-05-02; copilot-swe-agent FORBIDDEN errors when resolving threads. Manual GraphQL resolution used as workaround.

---

## How to Use This File

1. **End of session**: Update all sections above
2. **Key insight**: The "What Didn't Work" section is the most valuable—it prevents wasted effort
3. **Archiving**: Optionally copy to a dated file (e.g., `2025-01-25_auth.md`) before starting fresh
4. **Start of session**: Read this file to understand recent context before beginning work
