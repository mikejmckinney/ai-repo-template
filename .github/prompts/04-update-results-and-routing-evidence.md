# Update targeted context-pack benchmark results and routing evidence

## Role and objective

You are the benchmark results editor. Update the benchmark results after targeted context-pack runs have completed and blind scores are locked.

Do not change production model routing or ADR policy unless the user explicitly asks for the separate ADR/update PR. This task is evidence capture and recommendation drafting only.

## Required startup

1. Read `AGENTS.md`.
2. Read `.context/benchmarks/model-roi/README.md`.
3. Read `.context/benchmarks/model-roi/benchmark-runbook.md`.
4. Read `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md`.
5. Read all targeted context-pack run artifacts:
   - `grading-sheet-blind.tsv`
   - `unsealed-map.tsv`
   - `meta-blind.json`
   - `meta-sealed.json`
   - `context-injection.json`
   - `diff.patch`

## Preconditions

Do not proceed unless:

- Blind scores are locked.
- Alias mapping has been unsealed after scoring.
- Each run has exactly one terminal result.
- Each pack run has valid context metadata.
- Any missing telemetry is explicitly recorded.

## Results section to add

Append a new section:

```markdown
## Stage 1E Targeted Context-Pack Results
```

Include:

```markdown
Stage 1E tests targeted context packs as a middle path between lazy loading and full `.context/rules/*.md` injection. It reuses the historical Class A and Class B frozen bases from issues #374/#376 and measures whether smaller named context bundles improve quality enough to offset added token/cache cost.
```

### Tables

Add a Class A table:

```markdown
### Stage 1E Class A: targeted context packs

| Alias | Platform/model | Context variant | Pack files | Pack bytes | Score /100 | Score delta | Wall s | Cost USD | ROI | ROI delta | Summary |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
```

Add a Class B table:

```markdown
### Stage 1E Class B: targeted context packs

| Alias | Platform/model | Context variant | Pack files | Pack bytes | Score /100 | Score delta | Wall s | Cost USD | ROI | ROI delta | Summary |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
```

Add a pack comparison table:

```markdown
### Context-pack comparison

| Task class | Pack | Mean score | Mean cost | Mean ROI | Scope-noise count | Process-miss count | Recommendation |
|---|---|---:|---:|---:|---:|---:|---|
```

### Notes

Record:

- Which pack won by raw score.
- Which pack won by marginal ROI.
- Whether the raw-score winner and ROI winner differ.
- Whether any model degraded under a pack by more than 3 points.
- Whether full-rule injection remained dominated.
- Whether baseline lazy loading remained best.
- Any missing telemetry and how it affects confidence.

## Recommendation language

Use restrained language:

```markdown
These results support `<pack-id>` as the default targeted pack for Class `<A|B>` benchmark-like work, subject to future reruns when model pricing or context loading behavior changes.
```

Avoid universal claims such as:

```text
best model overall
best context strategy for all repos
full context is always bad
```

## ADR / routing follow-up draft

If the results justify a policy change, create a draft follow-up subsection but do not edit ADR-019 unless explicitly asked:

```markdown
### Proposed follow-up: context loading policy

- Default: baseline lazy loading.
- Class A: `<pack-id>` when process adherence risk is high.
- Class B: `<pack-id>` when code/test reasoning risk is high.
- Avoid: full-rules injection by default.
- Exception: full-rules injection only for measured rescue cases or explicit human opt-in.
```

## Validation

Before finalizing:

```bash
grep -n "Stage 1E Targeted Context-Pack Results" .context/benchmarks/model-roi/results/agent-roi-benchmark-results.md
./test.sh
```

If `./test.sh` fails from pre-existing unrelated issues, document the exact failing check and why it is unrelated.
