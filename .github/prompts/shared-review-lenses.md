# Shared review contract

This is the canonical common contract for advisory, daily, and weekly review.
Cadence prompts define only their evidence boundary and output format.

## Common constraints

- Analyze and report only. Do not edit files, push commits, submit formal reviews,
  change labels or PR state, resolve threads, or open issues or pull requests.
- Report only concrete, actionable findings supported by supplied or repository
  evidence. Prefer no finding over speculation.
- Evaluate current state, not only historical evidence. Do not report an issue
  already resolved at the reviewed head.
- Deduplicate findings and accepted exceptions. Cite paths and reproduction
  evidence, and distinguish verified facts from uncertainty.

## Normalized AP11 observation contract

Every non-empty automated finding uses `triage_version: 2` and records
observations rather than model-authored severity or priority:

| Field | Values | Meaning |
|---|---|---|
| `impact` | `incorrect-behavior` \| `dx-perf-doc` \| `meta-harness` | Kind of affected behavior |
| `impact_magnitude` | `bounded` \| `material` \| `critical` | Consequence if triggered |
| `trigger_likelihood` | `common` \| `edge` \| `fringe` | Exposure frequency |
| `affected_scope` | `isolated` \| `limited` \| `broad` | Population or surface affected |
| `reversibility` | `easy` \| `moderate` \| `hard` | Recovery after occurrence |
| `fix_cost` | `trivial` \| `moderate` \| `large` | Mitigation cost |
| `confidence` | `low` \| `medium` \| `high` | Evidence confidence |
| `uncertainty` | non-empty string | Missing or uncertain evidence; use `none` only when verified |
| `regression_guard` | boolean | Cheap invariant or test value, not a general small-fix flag; independent of likelihood |

Automation validates these fields and derives `priority_band`. Review-surface
authority is separate: advisory output remains optional and non-blocking for
every derived band. A regression guard never raises the priority of a
`trigger_likelihood: fringe` finding. Do not reproduce or improvise the
classifier decision table in a prompt.

## Lenses

Apply these lenses proportionally to the available evidence.

1. **Outcome and scope:** Does the change solve the stated user problem without unrelated scope or hidden assumptions?
2. **Correctness:** Check realistic inputs, edge cases, regressions, failure paths, and silent error handling.
3. **Tests:** Evaluate behavioral coverage, assertion quality, determinism, and whether tests would fail for the reported defect.
4. **Security and privacy:** Look for unsafe trust boundaries, credential or data exposure, injection, and excessive permissions.
5. **Compatibility:** Check published interfaces, persisted data, migrations, installation, and downstream consumers.
6. **Reliability and performance:** Check retries, cleanup, concurrency, bounded resource use, and avoidable hot-path cost.
7. **Maintainability:** Flag dead or speculative code, unclear ownership, unnecessary coupling, and abstractions that obscure control flow.
8. **Documentation and process truth:** Verify active docs, ADRs, templates, inventories, and automation describe the implemented behavior.
9. **Evidence and noise discipline:** Cite paths and reproduction evidence, deduplicate prior findings, honor accepted exceptions, and distinguish facts from uncertainty.

## Persisted keyed-state matrix

Apply this matrix only when the reviewed behavior appends, merges, upserts,
replaces, migrates, deduplicates, or otherwise persists records by key. Verify
the intended result and effective regression evidence for:

- first write;
- identical retry;
- changed retry;
- unrelated-key preservation;
- duplicate legacy records;
- missing-field compatibility.

Do not require this matrix for changes without persisted keyed state.
