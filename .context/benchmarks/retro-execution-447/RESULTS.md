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

## Results table

| Arm | Strategy | `run_date` | Wall clock (job) | Retro-only (approx) | Findings | Superseded | LLM calls (retro) | Provider | Run URL | Umbrella |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| **A** | Sequential per-PR | `2026-06-24` | **16m 53s** | **~13m 3s** | **14** | 3 (fix prefilter) | 6 + 1 fix | Cursor `composer-2.5-standard` | [27796546251](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251) | [sandbox #73](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/73) |
| **B** | Monolithic (1× LLM) | `2026-06-25` | **2m 40s** | **~2m 2s** | **8** | n/a (`skip_fix`) | **1** | Cursor `composer-2.5-standard` | [27797882347](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27797882347) | [sandbox #92](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/92) |
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

- **Finding count variance** (14 / 8 / 16) — LLM non-determinism + monolithic bundling may miss per-PR nuance; not a quality tie.
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
| **Retro wall clock** | **Arm B (monolithic)** | ~2m vs ~4.5m (C) vs ~13m retro-only (A) |
| **LLM cost (calls)** | **Arm B** | 1 call vs 6 for A/C |
| **Isolation / debuggability** | **Arm A (sequential)** | Per-PR artifacts, prompts, failures |
| **Finding completeness (uncertain)** | **Inconclusive** | Counts diverged; monolithic may under-report |
| **Context window risk** | **Arm A/C** | Monolithic prompt grows with PR count + diff size |

**Suggested path**

1. **Keep sequential as production default** — best isolation, matches current ops, lowest parse-failure blast radius.
2. **Optional monolithic mode** for bounded smoke windows (e.g. ≤6 PRs, `skip_fix` benchmarks) when latency matters and operators accept quality spot-checks.
3. **Parallel mode** as middle ground when sequential latency hurts but monolithic context/parsing risk is too high — ~2× faster than sequential retro-only in this run, but 6× LLM cost vs monolithic.

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

**Interpretation:** Count variance is mostly **LLM non-determinism**, not pipeline dedupe. Monolithic (B) **under-reports** (missed all PR #85 themes; 0 exact key matches with A/C). A and C also disagree (12 A-only keys, 14 C-only keys).

### Theme-level comparison (semantic clusters)

Title similarity ≥72% within the same PR. **Present** = at least one finding in that theme in the arm.

| Theme (PR) | A | B | C | Triage | Notes |
|---|---|---|---|---|---|
| `mark-superseded` substring false positive | ✓ | ✓ | ✓ | **Fix** | Layer C can skip real fixes; prefix `path in text` is a real bug |
| `mark-superseded` directory (`is_file` only) | ✓ | ✓ | ✓ | **Should fix** | Edge case (dir vs file); small change, low risk |
| Umbrella subprocess-per-finding | ✓ | ✓ | ✓ | **Defer** | Perf nit; matters only on very large batches |
| Fix re-exec WORKDIR temp leak | ✓ | ✓ | ✓ | **Should fix** | Orphaned `/tmp` each fix pass; easy fix, flagged pre-merge |
| Truncated JSON snapshot unrestorable | ✓ | ✓ | ✓ | **Should fix** | Real `fix_only` failure when snapshot exceeds cap; rare but high impact |
| merge SHA `gh pr view` fallback | ✓ | ✗ | ✓ | **Should fix** | Layer A dedupe silently weakens; one-line `gh api` fallback |
| PIPESTATUS error message unreachable | ✓ | ✗ | ✗ | **Defer** | Job still fails; DX/logging only |
| cap-json minimal-body shrink edge | ✓ | partial | ✓ | **Defer** | Unusual review JSON shapes; fails safe to `[]` |
| No-op fix rerun stale draft PR | ✓ | partial | ✓ | **Should fix** | Operator confusion on re-dispatch; skip `gh pr edit` when `has_diff=0` |
| ADR-030 snapshot recovery doc | ✓ | ✗ | ✓ | **Defer** | Doc/process follow-up after truncation behavior is decided |
| PR #85 sandbox verification meta (×4) | ✓ | ✗ | ✓ | **Defer / meta** | Sandbox dogfood hygiene, not production defects |
| PR #87 RUN_DATE + artifact invariants | ✗ | ✗ | ✓ | **Should fix** | Cheap `052` invariant rows; prevents silent regression |

### Priority bands (recommended)

| Band | Themes | Action |
|---|---|---|
| **Fix now** (1) | superseded substring | Incorrect Layer C behavior |
| **Should fix** (6) | directory exists, WORKDIR leak, truncated snapshot, merge-sha fallback, noop fix rerun, #87 invariants | Real bugs or cheap regression guards |
| **Defer** (5+) | subprocess perf, PIPESTATUS message, cap-json edge, ADR doc, most #85 meta | Fringe, DX, or process — file `agent-suggested` or close as won't-fix |

**Not every legitimate finding needs a fix PR.** Retro is tuned to prefer evidence-backed suggestions (ADR-027); sandbox-heavy PRs (#85) inflate meta findings. Use umbrella **Suggested fix** + severity + repro likelihood before opening fix work.

