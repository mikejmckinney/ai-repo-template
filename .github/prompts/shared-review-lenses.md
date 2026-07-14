# Shared review lenses

Apply these lenses proportionally to the supplied evidence. Report only concrete,
actionable findings; prefer no finding over speculation or duplicated noise.

1. **Outcome and scope:** Does the change solve the stated user problem without unrelated scope or hidden assumptions?
2. **Correctness:** Check realistic inputs, edge cases, regressions, failure paths, and silent error handling.
3. **Tests:** Evaluate behavioral coverage, assertion quality, determinism, and whether tests would fail for the reported defect.
4. **Security and privacy:** Look for unsafe trust boundaries, credential or data exposure, injection, and excessive permissions.
5. **Compatibility:** Check published interfaces, persisted data, migrations, installation, and downstream consumers.
6. **Reliability and performance:** Check retries, cleanup, concurrency, bounded resource use, and avoidable hot-path cost.
7. **Maintainability:** Flag dead or speculative code, unclear ownership, unnecessary coupling, and abstractions that obscure control flow.
8. **Documentation and process truth:** Verify active docs, ADRs, templates, inventories, and automation describe the implemented behavior.
9. **Evidence and noise discipline:** Cite paths and reproduction evidence, deduplicate prior findings, honor accepted exceptions, and distinguish facts from uncertainty.
