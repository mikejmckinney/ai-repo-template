# Model ROI benchmark — deferred follow-ups

Tracked from PR [#379](https://github.com/mikejmckinney/ai-repo-template/pull/379) bot review triage (2026-06-08).
Phase A merged in `eb8fff6`; fixture retention on branch `benchmark/roi` and tag
`benchmark/phase-a-artifacts-20260608`.

## P2 harness / tooling

| Item | File | Notes |
|---|---|---|
| Parse sealed maps after comment header | `scripts/benchmark/compare-grade-sets.py` | Low risk for canonical `regrade-stage.sh` path |
| Run disabled acceptance commands with `--run-checks` | `scripts/benchmark/grading_lib.py` | Edge case for task specs with intentionally disabled checks |
| Context-pack manifest missing trailing newline | `scripts/benchmark/lib.sh` | `read` may return non-zero; use `|| true` or normalize manifests |
| Replace `sed -n '1,$p'` with `cat` | `scripts/benchmark/lib.sh` | Style/portability only |
| Median aggregation across multiple graders | `scripts/benchmark/grading_lib.py` | Canonical path uses single `cursor-llm-blind-v1` grader |
| Require requested grader's subjective file on compile | `scripts/benchmark/grading_lib.py` | Stricter compile gate for multi-grader score sets |

## Platform / data

| Item | Notes |
|---|---|
| macOS Bash 3.2 | `prepare-grade-bundle.sh` needs Bash 4+ (`declare -A`, `mapfile`). Documented in `grading/README.md`; Homebrew `bash` or Linux CI required |
| Gemini `cand-21-pipe` cost telemetry | Published as `N/A` until Antigravity session recovery (see `results.md` recovery notes) |

## Suggested tracking

Open dedicated issues when picking these up; link back to this file and #374.
