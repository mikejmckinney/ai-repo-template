# Open Issue Audit: 2026-07-20

Status: Read-only disposition plan

Baseline: `main` at `bf500dd2f61aba82194f91619ad9a47c5793df3d`

Related planning issue: [#357](https://github.com/mikejmckinney/ai-repo-template/issues/357)

Planning PR: [#497](https://github.com/mikejmckinney/ai-repo-template/pull/497)

This audit reviews every issue open at the capture time, including generated
weekly/retro umbrellas, tracking parents, and child issues. It recommends issue
dispositions but does not authorize or perform issue mutations.

## Method

The audit captured 55 open issue bodies, comments, labels, closing-PR
references, and parent/sub-issue relationships. Three prior Fusion panel
sessions were continued so they retained the AP2 review context:

- Sol panel: `ses_082aa6ba2ffeUXzBc9q1DG40Hb`
- Fable panel: `099accd4-2c97-45e1-9efd-c0491ce75c10`
- Grok panel: `4b994bc5-6148-4e37-acaf-62686d531e9d`
- Sol judge: `ses_082a39fa3ffesGF3YMBvO6RUxQ`

Each panel returned exactly 55 issue rows. The judge adjudicated disagreements
against repository sources and live read-only GitHub evidence rather than by
majority vote. Closure-sensitive live-defect claims were then independently
verified before this report was recorded.

## Portfolio Findings

1. Most open issues describe the role registry, structured compliance,
   Copilot dispatch, local coordination state, or workflows retired by ADR-031
   and ADR-025. Thirty-six issues can close obsolete or not planned.
2. Generated review umbrellas cannot be closed by age or shared baseline alone.
   Issues 443, 455, 465, 475, and 496 contain verified current defects.
3. Issue 357 is the correct implementation center for current AP2 work, but its
   body must be rebaselined from deleted role/workflow surfaces to the approved
   plan in `docs/research/issue-357-ap2-refactor-plan.md`.
4. Issue 496 is the highest-priority retained defect issue because its schema,
   validator, fixture, and optional dependency behavior currently disagree.
5. Parent and child issue maps are stale. Children must be dispositioned before
   closing or rewriting their parents so valid surviving scope is not lost.

## Verified Live Defects

### Issue 443: sandbox credential handling

`scripts/workflows/lib/sandbox-sync-fix-branch.sh:53-80` overwrites `GH_TOKEN`
without restoring the caller's value and embeds `SANDBOX_BOOTSTRAP_TOKEN` in a
Git push URL. Issue 443 must be rebaselined to these findings before issue 442
closes as its duplicate.

### Issue 455: superseded-finding detection

`scripts/workflows/lib/superseded_findings.py:7-15` uses generic hints such as
`missing`, `lack`, and `without`. Lines 50-80 resolve candidate paths without
proving the result remains under `repo_root`. Both can produce incorrect
supersession decisions.

### Issue 465: weekly evidence validation

`validate-weekly-review.py:38-59` and
`validate-weekly-review-batch.py:45-69` require reproduction steps but do not
require `evidence[]`. Preserve this finding before closing later same-baseline
weekly review issues.

### Issue 475: review harness gaps

- `scripts/checks/055-script-syntax.sh:21-34` excludes shell scripts below
  `.agents/skills/**` despite claiming to cover every authored shell script.
- Check 053 requires the `batch_fix_publish` guard, while check 052 does not.
- Weekly provider selection can return an unsupported configured value, while
  the scan dispatch has no default provider case.

### Issue 496: retro schema/runtime divergence

- `.github/schemas/postmerge-retro.schema.json:6-18` requires
  `evidence_complete: true`.
- `validate-postmerge-retro.py:64-75` requires it only when a flag is passed.
- `scripts/tests/fixtures/postmerge-retro/sample-retro.json:1-21` omits it.
- `validate-postmerge-retro-daily.py:111-119` silently skips schema validation
  when `jsonschema` is unavailable.

## Issue Dispositions

| Issue | Recommendation | Completed scope | Remaining/current problem | Proposed action |
|---:|---|---|---|---|
| [#54](https://github.com/mikejmckinney/ai-repo-template/issues/54) | `CLOSE_OBSOLETE` | None verified | Unbounded attachment/model POC uses stale framing | Close not planned by maintainer decision |
| [#77](https://github.com/mikejmckinney/ai-repo-template/issues/77) | `CLOSE_OBSOLETE` | Historical model update | Backlog workflow and data source are gone | Close not planned |
| [#111](https://github.com/mikejmckinney/ai-repo-template/issues/111) | `CLOSE_OBSOLETE` | Copilot research remains historical | Role-dispatch overlays retired | Close not planned |
| [#129](https://github.com/mikejmckinney/ai-repo-template/issues/129) | `CLOSE_OBSOLETE` | Original review findings historically addressed | Gemini review surface removed | Close not planned |
| [#155](https://github.com/mikejmckinney/ai-repo-template/issues/155) | `CLOSE_OBSOLETE` | Issue-body plan model later landed | Backlog/prompt dispatch removed | Close with current plan pointer |
| [#163](https://github.com/mikejmckinney/ai-repo-template/issues/163) | `REBASELINE` | Setup checks current credentials | Derived-repo secret and variable bootstrap remains manual | Rewrite for OpenCode, sandbox, MCP, and provider credentials |
| [#200](https://github.com/mikejmckinney/ai-repo-template/issues/200) | `CLOSE_OBSOLETE` | ADR-014 remains historical | Analyst preflight gate retired | Close not planned |
| [#236](https://github.com/mikejmckinney/ai-repo-template/issues/236) | `CLOSE_OBSOLETE` | Historical relay fixes | Relay workflow removed | Close not planned |
| [#263](https://github.com/mikejmckinney/ai-repo-template/issues/263) | `CLOSE_OBSOLETE` | GitHub-first state landed | Repository state-writeback workflow superseded | Close as superseded by ADR-025 |
| [#279](https://github.com/mikejmckinney/ai-repo-template/issues/279) | `REBASELINE` | Setup modularized; legacy workflows removed | Epic body and child map are stale | Rewrite around narrowed #286 and #357 |
| [#283](https://github.com/mikejmckinney/ai-repo-template/issues/283) | `CLOSE_OBSOLETE` | One active label declaration exists | Proposed Copilot/budget manifests are stale | Carry bounded current-label validation into #357, then close |
| [#284](https://github.com/mikejmckinney/ai-repo-template/issues/284) | `CLOSE_OBSOLETE` | None applicable | Described Copilot state machine is retired | Close not planned |
| [#285](https://github.com/mikejmckinney/ai-repo-template/issues/285) | `CLOSE_OBSOLETE` | Current workflows already delegate to scripts | Pilot target workflow was deleted | Close not planned |
| [#286](https://github.com/mikejmckinney/ai-repo-template/issues/286) | `REBASELINE` | Label portion moves to #357 | Shell convention linter lacks fixture coverage | Narrow to linter fixture tests |
| [#293](https://github.com/mikejmckinney/ai-repo-template/issues/293) | `CLOSE_OBSOLETE` | Live state moved to GitHub | Lock/state sync surfaces removed | Close not planned |
| [#296](https://github.com/mikejmckinney/ai-repo-template/issues/296) | `CLOSE_OBSOLETE` | Synthesis exists as a skill | Permanent Synthesizer role conflicts with ADR-031 | Close not planned |
| [#299](https://github.com/mikejmckinney/ai-repo-template/issues/299) | `REBASELINE` | Rotation and retrospective/live split documented | Retention bound, promote/prune, and downstream clearing remain | Trim body to remaining policy |
| [#300](https://github.com/mikejmckinney/ai-repo-template/issues/300) | `CLOSE_OBSOLETE` | Consensus skill validates panel work | Legacy role/tool experiment retired | Close not planned |
| [#315](https://github.com/mikejmckinney/ai-repo-template/issues/315) | `CLOSE_OBSOLETE` | Historical compliance evidence remains | Runtime compliance stage retired | Close not planned |
| [#316](https://github.com/mikejmckinney/ai-repo-template/issues/316) | `REBASELINE` | Sandbox sibling procedure documented | Sandbox-local circularity carve-out remains absent | Rewrite as guide-only amendment |
| [#321](https://github.com/mikejmckinney/ai-repo-template/issues/321) | `CLOSE_OBSOLETE` | Auto-merge retains a settle window | Proposed review machinery is retired | Close by maintainer decision; retain current merge model |
| [#322](https://github.com/mikejmckinney/ai-repo-template/issues/322) | `REBASELINE` | Onboarding skill handles one repository | Cross-repository portfolio workflow needs current design | Rewrite as optional skill and validate external portfolio |
| [#327](https://github.com/mikejmckinney/ai-repo-template/issues/327) | `CLOSE_COMPLETED` | Three children completed | Remaining children target retired work | Close after #331 and #370 with mixed completed/retired note |
| [#331](https://github.com/mikejmckinney/ai-repo-template/issues/331) | `CLOSE_OBSOLETE` | Current policy uses one linked draft PR | Proposed rule, prompt, Judge, and gate surfaces are gone | Close not planned |
| [#339](https://github.com/mikejmckinney/ai-repo-template/issues/339) | `CLOSE_OBSOLETE` | None current | Entire gate epic targets retired architecture | Close after children |
| [#340](https://github.com/mikejmckinney/ai-repo-template/issues/340) | `CLOSE_OBSOLETE` | None | Analyst gate detection retired | Close not planned |
| [#341](https://github.com/mikejmckinney/ai-repo-template/issues/341) | `CLOSE_OBSOLETE` | None | Artifact verification depends on retired schema | Close not planned |
| [#342](https://github.com/mikejmckinney/ai-repo-template/issues/342) | `CLOSE_OBSOLETE` | None | Deferred token design prerequisites are obsolete | Close not planned |
| [#343](https://github.com/mikejmckinney/ai-repo-template/issues/343) | `CLOSE_OBSOLETE` | Opportunity feedback currently works | Original longitudinal metrics cannot be reconstructed honestly | Close obsolete by maintainer decision |
| [#346](https://github.com/mikejmckinney/ai-repo-template/issues/346) | `CLOSE_OBSOLETE` | Monolithic model removed dispatch pattern | Ownership-map enforcement no longer applies | Close not planned |
| [#347](https://github.com/mikejmckinney/ai-repo-template/issues/347) | `CLOSE_OBSOLETE` | None current | ADR-028 validator architecture retired | Close not planned |
| [#350](https://github.com/mikejmckinney/ai-repo-template/issues/350) | `CLOSE_OBSOLETE` | None | Exemption predicates depend on retired compliance | Close not planned |
| [#352](https://github.com/mikejmckinney/ai-repo-template/issues/352) | `CLOSE_COMPLETED` | Token precedence and PAT fallback documented | No current user-outcome gap verified | Close completed |
| [#353](https://github.com/mikejmckinney/ai-repo-template/issues/353) | `CLOSE_OBSOLETE` | Current runtime has separate profiles | Per-role terminal grants retired | Close not planned |
| [#354](https://github.com/mikejmckinney/ai-repo-template/issues/354) | `CLOSE_OBSOLETE` | Sandbox evidence remains an outcome gate | Path-overlap proxy is not valid outcome evidence | Close not planned |
| [#355](https://github.com/mikejmckinney/ai-repo-template/issues/355) | `CLOSE_OBSOLETE` | Compliance-heavy template sections removed | Residual stale-template cleanup belongs to #357 | Carry residual scope, then close |
| [#356](https://github.com/mikejmckinney/ai-repo-template/issues/356) | `CLOSE_OBSOLETE` | None current | Role/platform taxonomy retired | Close not planned |
| [#357](https://github.com/mikejmckinney/ai-repo-template/issues/357) | `REBASELINE` | Approved plan recorded on PR #497 | Body targets deleted mirrors | Replace body with approved current plan and implement |
| [#359](https://github.com/mikejmckinney/ai-repo-template/issues/359) | `CLOSE_OBSOLETE` | Actual children #360 and #362 completed | Unfiled remainder targets retired runtime | Close with completed-child note |
| [#370](https://github.com/mikejmckinney/ai-repo-template/issues/370) | `CLOSE_OBSOLETE` | Guide reduced and refreshed | Generator premise depends on removed catalogs | Close as disproportionate |
| [#371](https://github.com/mikejmckinney/ai-repo-template/issues/371) | `CLOSE_OBSOLETE` | Workflow count reduced | Blocking line ceiling does not prove AP8 | Close; retain line count as advisory evidence only |
| [#378](https://github.com/mikejmckinney/ai-repo-template/issues/378) | `CLOSE_COMPLETED` | Benchmark screen and accepted close criteria completed | None verified | Close completed |
| [#429](https://github.com/mikejmckinney/ai-repo-template/issues/429) | `CLOSE_OBSOLETE` | Several lifecycle fixes landed | Reviewed implementation was materially replaced | Close historical snapshot |
| [#434](https://github.com/mikejmckinney/ai-repo-template/issues/434) | `CLOSE_OBSOLETE` | Recovery and issue-body plans later landed | Handshake/compliance findings target removed surfaces | Close not planned |
| [#436](https://github.com/mikejmckinney/ai-repo-template/issues/436) | `CLOSE_COMPLETED` | Per-turn checkpoints and exact-session recovery landed | Optional Cursor hooks not required for outcome | Close completed |
| [#442](https://github.com/mikejmckinney/ai-repo-template/issues/442) | `CLOSE_DUPLICATE` | Later rerun exists | Same review window as #443 | Carry live findings, then close duplicate of #443 |
| [#443](https://github.com/mikejmckinney/ai-repo-template/issues/443) | `REBASELINE` | Role/compliance findings retired | Token-in-URL and token-restoration defects remain | Trim to live security findings and prioritize |
| [#455](https://github.com/mikejmckinney/ai-repo-template/issues/455) | `REBASELINE` | RUN_DATE/artifact invariants landed | Supersession false positives and containment remain | Trim to supersession hardening |
| [#465](https://github.com/mikejmckinney/ai-repo-template/issues/465) | `REBASELINE` | Role/bootstrap findings retired | Weekly validators omit evidence arrays | Retain only evidence-validation finding |
| [#466](https://github.com/mikejmckinney/ai-repo-template/issues/466) | `CLOSE_OBSOLETE` | Later retirement removed principal findings | No unique current finding verified | Close after carry-forward review |
| [#467](https://github.com/mikejmckinney/ai-repo-template/issues/467) | `CLOSE_OBSOLETE` | Later retirement removed principal findings | Draft PR #468 is stale | Close; do not merge stale PR |
| [#469](https://github.com/mikejmckinney/ai-repo-template/issues/469) | `CLOSE_COMPLETED` | Role references, budgets, checks, and docs corrected or retired | No surviving finding verified | Close completed; abandon stale PR #470 |
| [#475](https://github.com/mikejmckinney/ai-repo-template/issues/475) | `REBASELINE` | Stale prompt/rule findings removed | Three current harness gaps remain | Trim to syntax, guard, and provider-dispatch findings |
| [#495](https://github.com/mikejmckinney/ai-repo-template/issues/495) | `REBASELINE` | Kimi and plan-location docs partly corrected | `CLAUDE.md` inventory and generated plan blocks remain | Drop Kimi; fold plan generation into #357 |
| [#496](https://github.com/mikejmckinney/ai-repo-template/issues/496) | `RETAIN` | None of the main consistency fixes landed | Schema, fixture, validator, counters, and stale docs remain | Prioritize implementation and cross-link #357 overlaps |

## Totals

| Recommendation | Count |
|---|---:|
| `RETAIN` | 1 |
| `REBASELINE` | 12 |
| `CLOSE_COMPLETED` | 5 |
| `CLOSE_OBSOLETE` | 36 |
| `CLOSE_DUPLICATE` | 1 |
| **Total** | **55** |

If approved for execution, 42 issues close and 13 remain active.

## Dependency And Carry-Forward Map

- #442 duplicates #443. Put every surviving finding in #443 before closing
  #442.
- #279 remains the parent of narrowed #286 and rebaselined #357.
- Carry #283 current-label validation, #355 stale PR-template cleanup, and #495
  plan-scaffold generation into #357 before closing those obsolete scopes.
- Coordinate #316 with #357 where both touch sandbox/process guidance.
- Cross-link #496's stale ADR-029/PR-template findings to #357, but retain its
  schema/runtime defects independently.
- Close #331 and #370 before closing parent #327.
- Close #342, #341, and #340 before parent #339.
- Preserve the verified #465 finding before closing #466 and #467.
- #443 security work, #455 supersession hardening, #475 harness gaps, and #496
  schema/runtime work remain independent implementation tracks.

## Safe Mutation Order

1. Rebaseline #443, #455, #465, #475, #495, and cross-link #496 so no live
   finding is lost.
2. Rebaseline #357 from its approved plan and update #279's intended child map.
3. Close #442 as duplicate only after #443 contains every surviving finding.
4. Carry forward relevant scope, then close #283, #284, #285, #355, #356, and
   #371; narrow #286.
5. Close #342, #341, #340, then parent #339.
6. Close #331 and #370, then parent #327.
7. Close standalone obsolete issues and historical umbrellas.
8. Close completed issues #352, #378, #436, and #469; close #327 only after its
   children are dispositioned.
9. Rebaseline #163, #299, #316, #322, and the current-runtime issues.
10. Reconcile stale draft PRs #444, #468, and #470 separately. Do not merge them
    merely to close their issues.
11. Keep PR #497 as a planning record unless the maintainer later chooses to
    convert it into the issue 357 implementation PR.

## Issue 357 Plan Impact

The audit strengthens the approved AP2 plan and changes its issue relationships:

- Absorb current scope from #283, #355, and #495.
- Coordinate but do not absorb #286 and #316.
- Cross-link the overlapping stale-document findings from #496.
- Do not absorb #443, #455, #465, #475, or #496's runtime defects.
- Remove obsolete dependencies on #284, #285, #356, #370, and #371.

## Unverified Boundaries

- The external project portfolio and schema assumed by #322 were not inspected.
  The maintainer chose to rebaseline the issue as a skill; implementation still
  requires that external validation.
- Every historical finding in generated umbrellas was not replayed. Closure
  decisions use current source evidence plus documented architectural retirement.
- Draft PRs #444, #468, and #470 were not fully diff-reviewed.
- No local test suite or sandbox workflow was executed because this was a
  read-only issue audit rather than an implementation.

## Overall Assessment

The backlog can be reduced from 55 to 13 active issues, but not through blind
bulk closure. Preserve and prioritize the verified findings in #443 and #496,
then rebaseline the other current defects and issue 357 before performing the
bottom-up closure pass.
