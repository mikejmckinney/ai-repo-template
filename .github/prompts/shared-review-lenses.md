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
