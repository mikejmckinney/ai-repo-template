# Issue #447 — Retro execution benchmark results

Prototype branch: `bench/447-retro-execution`  
Prototype PR: [#453](https://github.com/mikejmckinney/ai-repo-template/pull/453)  
Plan: [#447 comment](https://github.com/mikejmckinney/ai-repo-template/issues/447#issuecomment-4746808980)

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

## Results table

| Arm | Strategy | `run_date` | Wall clock (job) | Retro-only (approx) | Findings | Superseded | LLM calls (retro) | Provider | Run URL | Umbrella |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| **A** | Sequential per-PR | `2026-06-24` | **16m 53s** | **~13m 3s** | **14** | 3 (fix prefilter) | 6 + 1 fix | Cursor `composer-2.5-standard` | [27796546251](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251) | [sandbox #73](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/73) |
| **B** | Monolithic (1× LLM) | `2026-06-25` | **2m 40s** | **~2m 2s** | **8** † | n/a (`skip_fix`) | **1** | Cursor `composer-2.5-standard` | [27797882347](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797882347) | [sandbox #92](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/92) |
| **C** | Parallel per-PR | `2026-06-26` | **4m 39s** | **~4m 36s** | **16** | n/a (`skip_fix`) | **6** | Cursor (6× parallel) | [27797996992](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797996992) | [sandbox #93](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/93) |

### Shared dispatch inputs

```text
context_profile=full
only_prs=90,87,85,83,63,45
force_re_retro_prs=90,87,85,83,63,45
```

Arm-specific:

| Arm | `benchmark_arm` | `run_date` | `skip_fix` |
|---|---|---|---|
| A | `sequential` (default) | `2026-06-24` | false (fix ran → sandbox draft PR #91) |
| B | `monolithic` | `2026-06-25` | true |
| C | `parallel` | `2026-06-26` | true |

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

### Spot-check (5 findings) — Arm A

| Dedupe key | Verdict | Notes |
|---|---|---|
| `pr90-path-substring-false-positive` | Actionable | Real Layer C logic risk |
| `pr83-truncated-snapshot-unrestorable` | Actionable | Known snapshot truncation failure mode |
| `pr54-only-prs-whitespace` | Possibly stale | Verify on HEAD before fix |
| `pr85-missing-fix-job-dispatch` | Meta / sandbox | Sandbox verification hygiene |
| `pr63-reexec-workdir-leak` | Actionable | Plausible temp-dir leak |

### Caveats (all arms)

- **Arm B diff budget (R1/R2):** Default `POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR` was **`POSTMERGE_RETRO_DIFF_LIMIT / 4` (75,000 bytes/PR)** while Arms A and C used the full per-PR cap (**300,000**). Arm B completeness vs A/C is **not fair** until **R3** at full budget (`run_date=2026-06-30`). † = R1/R2 finding counts under-trusted for completeness comparison.
- **Finding count variance** (14 / 8 † / 16) — LLM non-determinism + monolithic bundling/truncation may miss per-PR nuance; not a quality tie.
- **Arm A included fix**; B/C used `skip_fix=true` for retro timing fairness.
- **#438 proxy** on sandbox (PR #45).
- **Domain skew:** pipeline/retro-heavy PR set (expected).

## Prototype implementation (PR #453)

| Path | Purpose |
|---|---|
| `run-postmerge-retro-daily-dispatch.sh` | Routes `benchmark_arm` → sequential / monolithic / parallel |
| `run-postmerge-retro-monolithic.sh` | One LLM call, `split-monolithic-retro-json.py` |
| `run-postmerge-retro-parallel.sh` | Fan-out `run-postmerge-retro.sh` with `wait` |
| `daily-retro-select-prs.sh` | Shared PR selection + Layer A dedupe |
| `agent-postmerge-retro.yml` | Inputs `benchmark_arm`, `skip_fix` |

## Recommendation

| Criterion | Winner | Notes |
|---|---|---|
| **Retro wall clock** | **Arm B (monolithic)** † | ~2m vs ~4.5m (C) vs ~13m retro-only (A); R1/R2 B used ¼ diff budget |
| **LLM cost (calls)** | **Arm B** | 1 call vs 6 for A/C |
| **Isolation / debuggability** | **Arm A (sequential)** | Per-PR artifacts, prompts, failures |
| **Finding completeness** | **Arm A/C** | B R3 at full diff: **9** findings vs A **14** / C **16**; monolithic still under-reports |
| **Context window risk** | **Arm A/C** | Monolithic prompt grows with PR count + diff size |

**Suggested path**

1. **Keep sequential as production default** — best isolation, matches current ops, lowest parse-failure blast radius.
2. **Upgrade to parallel (C)** if retro latency becomes painful — ~2× faster retro-only than A in R1/R2 with same per-PR diff budget as sequential.
3. **Do not adopt monolithic for completeness-sensitive runs** — R3 at full per-PR diff (300k) yielded **9** findings vs **8** at ¼ budget; still missed all PR #85/#87 themes present in A/C. Speed advantage stands; completeness does not.

**Follow-up (out of scope for #453 merge):** file issue to harden monolithic JSON schema validation, add `skip_fix` to scheduled runs documentation, and resolve sandbox #82 so upstream #438 maps 1:1.

## Cross-arm findings comparison

Source: `daily-retro.json` artifacts from runs [A](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251), [B](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797882347), [C](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797996992).

### Summary statistics

| Metric | Arm A | Arm B | Arm C |
|---|---:|---:|---:|
| Total findings | 14 | 8 | 16 |
| PRs with ≥1 finding | 63, 83, 85, 90 | 63, 83, 90 | 63, 83, 85, 87, 90 |
| Exact `dedupe_key` overlap A∩C | — | — | **2** |
| Exact `dedupe_key` overlap A∩B or B∩C | — | **0** | **0** |
| Semantic clusters in all 3 arms | — | **5** | **5** |

**Interpretation:** Count variance is mostly **LLM non-determinism**, not pipeline dedupe. Monolithic (B) **under-reported in R1/R2** (missed all PR #85 themes; 0 exact key matches with A/C) — **confounded by ¼ per-PR diff budget**; R3 pending. A and C also disagree (12 A-only keys, 14 C-only keys).

## Finding priority classifier (manual scoring for #447)

Pending automation in a **separate PR** (schema + prompt + `classify-finding-priority.py`). Replaces deprecated `severity: low|medium|high` with **`impact`** and adds **`trigger_likelihood`**, **`fix_cost`**, optional **`regression_guard`**, and derived **`priority_band`**.

### LLM-emitted fields (future schema)

| Field | Values | Meaning |
|---|---|---|
| `impact` | `incorrect-behavior` \| `dx-perf-doc` \| `meta-harness` | Incorrect output on realistic input vs fails-safe DX/perf vs harness/sandbox meta |
| `trigger_likelihood` | `common` \| `edge` \| `fringe` | Fires on normal inputs vs unusual shape vs rare path |
| `fix_cost` | `trivial` \| `moderate` \| `large` | Implementation cost |
| `regression_guard` | `true` \| `false` (optional) | Set `true` only for invariant/test/check rows that prevent silent regression (`052` rows, etc.) |

Prompt rule: use `fix_cost=trivial` + `regression_guard=true` **only** for cheap test/invariant guards — not for general small fixes.

### Derived `priority_band` (deterministic — not LLM)

1. **`fix-now`** — `impact=incorrect-behavior` AND `trigger_likelihood=common`
2. **`should-fix`** — (`impact=incorrect-behavior` AND `trigger_likelihood=edge`) OR (`fix_cost=trivial` AND `regression_guard=true`)
3. **`defer`** — `impact∈{dx-perf-doc, meta-harness}` OR `trigger_likelihood=fringe` (unless `should-fix` via regression guard)

### Theme-level comparison (semantic clusters + classifier scores)

Manual scores applied to cross-arm themes (Arms A/C at full diff; B R1/R2 at ¼ diff — presence columns unchanged).

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

[#454](https://github.com/mikejmckinney/ai-repo-template/issues/454) tracks fix-now + should-fix themes (7 total under prior hand triage; classifier promotes WORKDIR leak to fix-now).

## Round 2 — variance rerun (2026-06-19)

**Goal:** Same PR set, new `run_date`s — measure finding stability vs Round 1.

**Codebase note:** Round 2 **Arm A** used **upstream `main`** (`a3a8820`, #452 only). Round 2 **B/C** used **sandbox `main` = `bench/447-retro-execution`** (`5ca2786`, includes #453 prototype) because `benchmark_arm` / `skip_fix` are not on upstream `main` yet.

| Arm | Round | `run_date` | Code @ sandbox `main` | Wall clock | Findings | Run |
|---|---|---|---|---:|---:|---|
| A | 1 | 2026-06-24 | `a3a8820` | 16m 53s | 14 | [27796546251](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251) |
| A | **2** | 2026-06-27 | **`a3a8820`** | **11m 46s** | **16** | [27800860456](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27800860456) |
| B | 1 | 2026-06-25 | `f4b9416` | 2m 40s | 8 | [27797882347](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797882347) |
| B | **2** | 2026-06-28 | `5ca2786` | **2m 26s** | **8** | [27801245644](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27801245644) |
| C | 1 | 2026-06-26 | `f4b9416` | 4m 39s | 16 | [27797996992](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797996992) |
| C | **2** | 2026-06-29 | `5ca2786` | **2m 53s** | **16** | [27801246377](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27801246377) |

### Round 1 vs Round 2 — exact `dedupe_key` overlap (same arm)

| Arm | R1∩R2 keys | Union | Interpretation |
|---|---:|---:|---|
| A | 3 | 27 | **High variance** — only 3/27 keys repeat |
| B | 1 | 15 | **High variance** — count stable (8) but keys differ |
| C | 1 | 31 | **High variance** — count stable (16) but keys differ |

Round 2 Arm A semantic theme overlap with Round 1 Arm A: **7/14** themes (title ≥72% match). **Core themes persist** (superseded substring/dir, WORKDIR leak, truncated snapshot) but wording/keys change.

**Arm B R1/R2 diff note:** Both used **75,000 bytes/PR** (default `diff_limit/4`). Not comparable to A/C for completeness.

## Arm B Round 3 — fair diff budget (2026-06-30)

**Goal:** Re-run monolithic at **full per-PR diff** (`POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR=300000`, matching A/C). Default changed from `diff_limit/4` → `diff_limit` in `run-postmerge-retro-monolithic.sh`.

| Arm | Round | `run_date` | Per-PR diff | Wall clock | Findings | PRs w/ findings | Run | Umbrella |
|---|---|---|---|---:|---:|---|---|---|
| B | **3** | `2026-06-30` | **300,000** | **2m 33s** | **9** | 63, 83, 90 | [27804588010](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27804588010) | [sandbox #98](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/98) |

Dispatch: `benchmark_arm=monolithic`, `skip_fix=true`, `monolithic_diff_per_pr=300000`, same `only_prs` / `force_re_retro_prs` as R1/R2. Env confirmed in run log: `POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR: 300000`.

**R3 vs R1/R2 B:** +1 finding (9 vs 8); same PR coverage (63, 83, 90). Still **no PR #85** themes (present in A/C). Exact `dedupe_key` overlap with Arm A R1: **1/22** union keys — semantic themes align better than keys.

**Conclusion:** ¼ diff budget was a confound for R1/R2, but **not the sole cause** of monolithic under-reporting. Even at fair budget, monolithic misses ~half the findings A/C surface on this PR set.

### Consolidated fix issue

[#454](https://github.com/mikejmckinney/ai-repo-template/issues/454) — 7 should-fix themes from triage; deferred items explicitly out of scope.


