# Issue #447 — Retro execution benchmark results

Prototype branch: `bench/447-retro-execution`  
Prototype PR: [#453](https://github.com/mikejmckinney/ai-repo-template/pull/453)  
Plan: [#447 comment](https://github.com/mikejmckinney/ai-repo-template/issues/447#issuecomment-4746808980)  
Finding classifier schema: [#456](https://github.com/mikejmckinney/ai-repo-template/issues/456) (planned)

## Sandbox PR mapping (upstream → sandbox)

Benchmark runs on `mikejmckinney/ai-repo-template-sandbox`. Upstream PR numbers do not exist there; equivalent **merged** sandbox PRs were used.

| Upstream | Sandbox | Notes |
|---|---|---|
| 452 | 90 | Merged after `main` sync |
| 451 | 87 | Merged after `main` sync |
| 441 | 85 | Already merged |
| 440 | 83 | Merged after `main` sync |
| 433 | 63 | Pipeline retro A/B |
| 438 | 45 | **Proxy:** upstream #438 has no merged sandbox PR (#82 conflict); used merged smoke canary #45 |

**Sandbox prep**

| Tag | When |
|---|---|
| `pre-bench-447-arm-a-20260618-235233` | Before Arm A (`origin/main` → `sandbox/main`) |
| `pre-bench-447-bc-20260619-003037` | Before Arms B/C (`bench/447-retro-execution` → `sandbox/main`) |
| `pre-bench-447-arm-b-r3-20260619-040248` | Before Arm B R3 (fair diff budget) |

## Results table (Round 1)

| Arm | Strategy | `run_date` | Wall clock (job) | Retro-only (approx) | Findings | Superseded | LLM calls (retro) | Provider | Run URL | Umbrella |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| **A** | Sequential per-PR | `2026-06-24` | **16m 53s** | **~13m 3s** | **14** | 3 (fix prefilter) | 6 + 1 fix | Cursor `composer-2.5-standard` | [27796546251](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251) | [sandbox #73](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/73) |
| **B** | Monolithic (1× LLM) | `2026-06-25` | **2m 40s** | **~2m 2s** | **8** † | n/a (`skip_fix`) | **1** | Cursor `composer-2.5-standard` | [27797882347](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797882347) | [sandbox #92](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/92) |
| **C** | Parallel per-PR | `2026-06-26` | **4m 39s** | **~4m 36s** | **16** | n/a (`skip_fix`) | **6** (max **6** concurrent) | Cursor (6× parallel) | [27797996992](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797996992) | [sandbox #93](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/93) |

† Arm B R1/R2 used **75,000 bytes/PR** diff cap (see [Arm B diff budget](#arm-b-diff-budget-caveat)).

### Fair comparison snapshot (A R1 vs C R1 vs B R3)

Use this row set when judging completeness — B R3 is the fair monolithic rerun at full per-PR diff.

| Arm | `run_date` | Per-PR diff | Findings | PRs with ≥1 finding | Wall clock |
|---|---|---:|---:|---|---:|
| **A** sequential | `2026-06-24` | 300,000 | 14 | 63, 83, 85, 90 | 16m 53s job (~13m retro) |
| **C** parallel | `2026-06-26` | 300,000 | 16 | 63, 83, 85, 87, 90 | 4m 39s |
| **B** monolithic | `2026-06-30` (R3) | 300,000 | 9 | 63, 83, 90 | 2m 33s |

### Shared dispatch inputs

```text
context_profile=full
only_prs=90,87,85,83,63,45
force_re_retro_prs=90,87,85,83,63,45
```

Arm-specific:

| Arm | `benchmark_arm` | `run_date` | `skip_fix` | Other |
|---|---|---|---|---|
| A | `sequential` (default) | `2026-06-24` | false (fix ran → sandbox draft PR #91) | — |
| B R1/R2 | `monolithic` | `2026-06-25` / `2026-06-28` | true | default 75k/PR diff |
| B R3 | `monolithic` | `2026-06-30` | true | `monolithic_diff_per_pr=300000` |
| C | `parallel` | `2026-06-26` | true | `POSTMERGE_RETRO_PARALLEL_MAX=6` (benchmark + production cap) |

### Arm A per-PR retro LLM duration (log timestamps, UTC)

| Sandbox PR | Upstream | Duration (approx) |
|---|---|---:|
| 90 | 452 | ~2m 05s |
| 87 | 451 | ~1m 36s |
| 85 | 441 | ~2m 20s |
| 83 | 440 | ~2m 54s |
| 63 | 433 | ~1m 16s |
| 45 | 438 (proxy) | ~2m 39s |

Fix pass LLM: ~3m 40s additional on Arm A.

### Spot-check (5 findings) — Arm A R1

| Dedupe key | Classifier band | Notes |
|---|---|---|
| `pr90-path-substring-false-positive` | **fix-now** | Layer C substring supersede |
| `pr83-truncated-snapshot-unrestorable` | **should-fix** | Snapshot truncation breaks `fix_only` |
| `pr54-only-prs-whitespace` | defer (stale?) | Not in R1 artifact; verify on HEAD |
| `pr85-missing-fix-job-dispatch` | **defer** | Sandbox/meta hygiene |
| `pr63-reexec-workdir-leak` | **fix-now** | Orphan `/tmp` on fix re-exec |

### Caveats (all arms)

- **Arm B diff budget (R1/R2):** See [dedicated section](#arm-b-diff-budget-caveat). R1/R2 B finding counts are **not** comparable to A/C for completeness.
- **Finding count variance** (14 / 8† / 16 / 9 R3) — LLM non-determinism; exact `dedupe_key` overlap is low across arms and rounds.
- **Arm A included fix**; B/C used `skip_fix=true` for retro timing fairness.
- **#438 proxy** on sandbox (PR #45) — no findings on PR 45 in A/B/C R1; proxy PR is in batch but retro may emit zero for low-signal merges.
- **Domain skew:** 5/6 upstream PRs are pipeline/retro-adjacent — meta/sandbox findings (#85) are expected.

## Prototype implementation (PR #453)

| Path | Purpose |
|---|---|
| `run-postmerge-retro-daily-dispatch.sh` | Routes `benchmark_arm` → sequential / monolithic / parallel |
| `run-postmerge-retro-monolithic.sh` | One LLM call, `split-monolithic-retro-json.py`; per-PR diff defaults to full `diff_limit` |
| `run-postmerge-retro-parallel.sh` | Fan-out `run-postmerge-retro.sh` with `wait`; cap concurrency via `POSTMERGE_RETRO_PARALLEL_MAX` (**6** for production) |
| `daily-retro-select-prs.sh` | Shared PR selection + Layer A dedupe |
| `agent-postmerge-retro.yml` | Inputs `benchmark_arm`, `skip_fix`, `monolithic_diff_per_pr` |

## Recommendation

| Criterion | Winner | Notes |
|---|---|---|
| **Retro wall clock** | **Arm B (monolithic)** | ~2.5m at fair diff; ~3× faster than C, ~5× than A retro-only |
| **LLM cost (calls)** | **Arm B** | 1 call vs 6 for A/C |
| **Ops debuggability** | **Arm A (sequential)** | Linear job log, fail-fast; not a different per-PR retro shape than C |
| **Finding completeness** | **Arm A/C** | B R3: **9** vs A **14** / C **16** at same per-PR diff |
| **Context window risk** | **Arm A/C** | Monolithic prompt grows with PR count + diff size |

**Suggested path**

1. **Keep sequential (A) as production default** — same per-PR retro unit as C; simplest logs, fail-fast, no concurrent provider pressure.
2. **Upgrade to parallel (C) when latency hurts** — same `run-postmerge-retro.sh` per PR as A; ~3× faster retro-only in R1. Set **`POSTMERGE_RETRO_PARALLEL_MAX=6`** (matches daily batch size cap; benchmark used 6 concurrent).
3. **Do not adopt monolithic for completeness-sensitive runs** — R3 at 300k/PR: **9** findings vs **8** at ¼ budget; still misses PR #85/#87 themes present in A/C. Speed/cost advantage only.

**Follow-up:** [#454](https://github.com/mikejmckinney/ai-repo-template/issues/454) (fixes), [#456](https://github.com/mikejmckinney/ai-repo-template/issues/456) (finding classifier schema), resolve sandbox #82 for #438 mapping.

## Cross-arm findings comparison (R1 artifacts)

Source: `daily-retro.json` from [A R1](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251), [B R1](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797882347), [C R1](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797996992). For monolithic completeness use **B R3** ([27804588010](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27804588010)) — not B R1.

### Summary statistics (R1)

| Metric | Arm A | Arm B R1 | Arm C |
|---|---:|---:|---:|
| Total findings | 14 | 8 † | 16 |
| PRs with ≥1 finding | 63, 83, 85, 90 | 63, 83, 90 | 63, 83, 85, 87, 90 |
| Exact `dedupe_key` overlap A∩C | — | — | **2** |
| Exact `dedupe_key` overlap A∩B or B∩C | — | **0** | **0** |
| Semantic clusters in all 3 arms | — | **5** | **5** |

**Interpretation:** Count variance is mostly **LLM non-determinism**, not pipeline dedupe. Monolithic **under-reports** even at fair diff (R3: 9 vs A 14 / C 16). A and C share the same per-PR script; C found slightly more in R1. Exact keys disagree heavily (A∩C: 2/28 union).

## Finding priority classifier (manual scoring for #447)

Automation tracked in [#456](https://github.com/mikejmckinney/ai-repo-template/issues/456). Replaces deprecated `severity: low|medium|high` with **`impact`** plus **`trigger_likelihood`**, **`fix_cost`**, optional **`regression_guard`**, and derived **`priority_band`**.

### LLM-emitted fields (future schema)

| Field | Values | Meaning |
|---|---|---|
| `impact` | `incorrect-behavior` \| `dx-perf-doc` \| `meta-harness` | Incorrect output on realistic input vs fails-safe DX/perf vs harness/sandbox meta |
| `trigger_likelihood` | `common` \| `edge` \| `fringe` | Fires on normal inputs vs unusual shape vs rare path |
| `fix_cost` | `trivial` \| `moderate` \| `large` | Implementation cost |
| `regression_guard` | `true` \| `false` (optional) | `true` only for invariant/test/check rows that prevent silent regression (`052` rows, etc.) |

Prompt rules:

- Use `fix_cost=trivial` + `regression_guard=true` **only** for cheap test/invariant guards — not for general small fixes.
- Do not set `regression_guard=true` on `trigger_likelihood=fringe` findings.

### Derived `priority_band` (deterministic — not LLM)

Evaluate in order; first match wins:

1. **`fix-now`** — `impact=incorrect-behavior` AND `trigger_likelihood=common`
2. **`should-fix`** — (`impact=incorrect-behavior` AND `trigger_likelihood=edge`) OR (`fix_cost=trivial` AND `regression_guard=true` AND `trigger_likelihood≠fringe`)
3. **`defer`** — everything else (including `impact∈{dx-perf-doc, meta-harness}` and `trigger_likelihood=fringe`)

### Theme-level comparison (semantic clusters + classifier scores)

Manual scores on cross-arm themes. **Presence (A/B/C columns):** R1 artifacts; B column reflects R1/R2 at ¼ diff (under-reports vs A/C).

| Theme (PR) | A | B | C | impact | trigger | fix_cost | guard | **band** | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `mark-superseded` substring false positive | ✓ | ✓ | ✓ | incorrect-behavior | common | moderate | false | **fix-now** | Layer C skips real fixes |
| `mark-superseded` directory (`is_file` only) | ✓ | ✓ | ✓ | incorrect-behavior | edge | trivial | false | **should-fix** | Dir vs file on HEAD |
| Umbrella subprocess-per-finding | ✓ | ✓ | ✓ | dx-perf-doc | fringe | moderate | false | **defer** | Perf; large batches only |
| Fix re-exec WORKDIR temp leak | ✓ | ✓ | ✓ | incorrect-behavior | common | trivial | false | **fix-now** | Orphan `/tmp` each fix pass |
| Truncated JSON snapshot unrestorable | ✓ | ✓ | ✓ | incorrect-behavior | edge | moderate | false | **should-fix** | Rare but breaks `fix_only` |
| merge SHA `gh pr view` fallback | ✓ | ✗ | ✓ | incorrect-behavior | edge | trivial | false | **should-fix** | Weakens Layer A dedupe |
| PIPESTATUS error message unreachable | ✓ | ✗ | ✗ | dx-perf-doc | fringe | trivial | false | **defer** | Job still fails |
| cap-json minimal-body shrink edge | ✓ | partial | ✓ | incorrect-behavior | fringe | moderate | false | **defer** | Fails safe to `[]` |
| No-op fix rerun stale draft PR | ✓ | partial | ✓ | incorrect-behavior | edge | trivial | false | **should-fix** | Operator confusion |
| ADR-030 snapshot recovery doc | ✓ | ✗ | ✓ | dx-perf-doc | edge | moderate | false | **defer** | Doc after truncation decision |
| PR #85 sandbox verification meta (×4) | ✓ | ✗ | ✓ | meta-harness | fringe | trivial | false | **defer** | Sandbox hygiene |
| PR #87 RUN_DATE + artifact invariants | ✗ | ✗ | ✓ | incorrect-behavior | edge | trivial | **true** | **should-fix** | `052` regression guard |

### Priority bands (classifier output)

| Band | Count | Themes |
|---|---:|---|
| **fix-now** | 2 | superseded substring, WORKDIR leak |
| **should-fix** | 5 | superseded directory, truncated snapshot, merge-sha fallback, noop fix rerun, #87 invariants |
| **defer** | 5+ | subprocess perf, PIPESTATUS, cap-json edge, ADR doc, #85 meta |

[#454](https://github.com/mikejmckinney/ai-repo-template/issues/454) tracks implementation for fix-now + should-fix themes (**7** total: 2 fix-now + 5 should-fix per classifier).

## Round 2 — variance rerun (2026-06-19)

**Goal:** Same PR set, new `run_date`s — measure finding stability vs Round 1.

**Codebase note:** Round 2 **Arm A** used **upstream `main`** (`a3a8820`). Round 2 **B/C** used **sandbox `main` = `bench/447-retro-execution`** because `benchmark_arm` / `skip_fix` are not on upstream `main` yet.

| Arm | Round | `run_date` | Code @ sandbox `main` | Wall clock | Findings | Run |
|---|---|---|---|---:|---:|---|
| A | 1 | 2026-06-24 | `a3a8820` | 16m 53s | 14 | [27796546251](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251) |
| A | **2** | 2026-06-27 | `a3a8820` | 11m 46s | 16 | [27800860456](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27800860456) |
| B | 1 | 2026-06-25 | `f4b9416` | 2m 40s | 8 † | [27797882347](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797882347) |
| B | **2** | 2026-06-28 | `5ca2786` | 2m 26s | 8 † | [27801245644](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27801245644) |
| C | 1 | 2026-06-26 | `f4b9416` | 4m 39s | 16 | [27797996992](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797996992) |
| C | **2** | 2026-06-29 | `5ca2786` | 2m 53s | 16 | [27801246377](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27801246377) |

### Round 1 vs Round 2 — exact `dedupe_key` overlap (same arm)

| Arm | R1∩R2 keys | Union | Interpretation |
|---|---:|---:|---|
| A | 3 | 27 | **High variance** — only 3/27 keys repeat |
| B | 1 | 15 | **High variance** — count stable (8†) but keys differ |
| C | 1 | 31 | **High variance** — count stable (16) but keys differ |

Round 2 Arm A semantic theme overlap with Round 1 Arm A: **7/14** themes (title ≥72% match). Core themes persist (superseded substring/dir, WORKDIR leak, truncated snapshot) but wording/keys change.

## Arm B diff budget caveat

| Round | `run_date` | `POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR` | Findings | Comparable to A/C? |
|---|---|---:|---:|---|
| R1 | 2026-06-25 | **75,000** (default `diff_limit/4`) | 8 | **No** |
| R2 | 2026-06-28 | **75,000** | 8 | **No** |
| **R3** | **2026-06-30** | **300,000** (explicit; default now full `diff_limit`) | **9** | **Yes** |

Arms A and C always used **300,000** bytes/PR via `POSTMERGE_RETRO_DIFF_LIMIT` in `run-postmerge-retro.sh`.

**R3 vs R1/R2:** +1 finding; same PR coverage (63, 83, 90). Still **no PR #85/#87** themes found in A/C. Exact `dedupe_key` overlap B R3 ∩ A R1: **1/22** union.

**Conclusion:** ¼ diff budget confounded R1/R2 but is **not the sole cause** of monolithic under-reporting.

| Arm | Round | `run_date` | Per-PR diff | Wall clock | Findings | PRs w/ findings | Run | Umbrella |
|---|---|---|---|---:|---:|---|---|---|
| B | **3** | `2026-06-30` | 300,000 | **2m 33s** | **9** | 63, 83, 90 | [27804588010](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27804588010) | [sandbox #98](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/98) |

Dispatch: `benchmark_arm=monolithic`, `skip_fix=true`, `monolithic_diff_per_pr=300000`, same `only_prs` / `force_re_retro_prs` as R1/R2.

### Consolidated fix issue

[#454](https://github.com/mikejmckinney/ai-repo-template/issues/454) — fix-now + should-fix themes from classifier; deferred items out of scope.
