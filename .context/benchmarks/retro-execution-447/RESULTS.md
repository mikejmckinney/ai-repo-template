# Issue #447 — Retro execution benchmark results

Prototype branch: `bench/447-retro-execution`  
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

**Sandbox prep:** tag `pre-bench-447-arm-a-20260618-235233`; force-pushed `origin/main` (`a3a8820`) to `sandbox/main` per playbook §1-alt.

## Results table

| Arm | Strategy | `run_date` | Wall clock (job) | Retro-only (approx) | Findings | Superseded (fix prefilter) | Provider | Run URL | Umbrella | Fix PR |
|---|---|---|---:|---:|---:|---:|---|---|---|---|
| **A** | Sequential per-PR (baseline) | `2026-06-24` | **16m 53s** | **~13m 3s** | **14** | **3** | Cursor `composer-2.5-standard` (×6 retro + ×1 fix) | [27796546251](https://github.com/mikejmckinney/ai-repo-template-sandbox/actions/runs/27796546251) | [sandbox #73](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/73) | [sandbox #91](https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/91) (draft) |
| B | Monolithic (prototype) | `2026-06-25` | — | — | — | — | — | — | — | — |
| C | Parallel fan-out (prototype) | `2026-06-26` | — | — | — | — | — | — | — | — |

### Arm A dispatch inputs (verbatim)

```text
context_profile=full
only_prs=90,87,85,83,63,45
run_date=2026-06-24
force_re_retro_prs=90,87,85,83,63,45
```

### Arm A per-PR retro LLM duration (log timestamps, UTC)

| Sandbox PR | Upstream | Start → end (approx) | Duration |
|---|---|---|---:|
| 90 | 452 | 23:54:01 → 23:56:06 | ~2m 05s |
| 87 | 451 | 23:56:07 → 23:57:43 | ~1m 36s |
| 85 | 441 | 23:57:43 → 00:00:03 | ~2m 20s |
| 83 | 440 | 00:00:03 → 00:02:57 | ~2m 54s |
| 63 | 433 | 00:02:58 → 00:04:14 | ~1m 16s |
| 45 | 438 (proxy) | 00:04:14 → 00:06:53 | ~2m 39s |

Fix pass LLM: ~00:07 → 00:10:40 (~3m 40s). Full job includes umbrella + artifact upload + fix.

### Spot-check (5 findings) — Arm A

| Dedupe key | Verdict | Notes |
|---|---|---|
| `pr90-path-substring-false-positive` | Actionable | Real Layer C logic risk; cites Gemini review + line refs |
| `pr83-truncated-snapshot-unrestorable` | Actionable | Matches known snapshot truncation failure mode |
| `pr54-only-prs-whitespace` | Possibly stale | `only_prs` stripping may already exist on HEAD — verify before fix |
| `pr85-missing-fix-job-dispatch` | Meta / sandbox | About sandbox verification PR hygiene, not production code |
| `pr63-reexec-workdir-leak` | Actionable | Plausible temp-dir leak in fix re-exec path |

### Arm A caveats

- Fix job ran (14 findings → draft PR #91). Wall clock includes fix; Arms B/C should document whether fix is skipped for fairness.
- Domain skew: heavy pipeline/retro meta findings (expected per plan).
- PR #87 and #45 produced **0 findings** in output (HEAD lens / smoke content).

## Recommendation (partial — pending B/C)

TBD after Arms B and C.
