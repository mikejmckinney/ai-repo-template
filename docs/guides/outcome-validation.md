# Outcome Validation

Use this guide to select a verification environment and publish evidence that
shows whether a change resolved its stated problem. Supporting tests remain
required, but they do not replace the affected user's journey.

## Terms

- **User-outcome validation** is the umbrella discipline.
- **End-to-end testing** is one method for executable journeys.
- **Supporting verification** includes unit, integration, regression, lint,
  schema, build, and CI checks.
- **Outcome-equivalent environment** is the least costly isolated environment
  preserving the conditions material to the outcome.
- **Environment adapter** is the concrete mechanism used for that environment.
- **Material claim** is an observation whose falsity would change the outcome
  conclusion.
- **Evidence artifact** is a durable redacted record supporting a material
  claim.

## Select the environment

Identify these load-bearing conditions before choosing an adapter:

1. Trigger or lifecycle phase.
2. User entrypoint and action.
3. Permissions and identity boundary.
4. Fresh versus existing state.
5. Platform and runtime.
6. Representative inputs and configuration.
7. Observable result that resolves the problem.

Use the least costly environment preserving all applicable conditions.

| Change | Representative adapter |
| --- | --- |
| Ordinary code | PR branch or local integration/E2E fixture |
| Static documentation | Rendered PR surface plus reader/comprehension procedure |
| Pull-request workflow | Current PR branch when the real trigger loads candidate code |
| Default-branch GitHub behavior | Sibling repository with candidate code on the required ref and the real event fired |
| Codespaces bootstrap | Newly created Codespace using the candidate startup path |
| Repository template/onboarding | Fresh disposable repository created from the candidate template |
| Website, API, or application | Provider preview with representative configuration and exercised user action |
| Database or infrastructure | Disposable branch, database, project, account, resource group, or stack |
| Operational guidance | Reader performs the procedure in its target environment |
| Mixed change | Separate evidence records for every load-bearing environment |

For default-branch GitHub behavior, follow
[`sandbox-verification.md`](sandbox-verification.md). The sibling repository is
an adapter for that constraint, not a universal destination.

## Identify material claims

Record observations that determine whether the outcome passed. Examples:

- an external resource exists with required ancestry or configuration;
- a permission was granted without removing existing grants;
- an actual event ran candidate workflow code;
- a user completed an action through a preview;
- a fresh repository or Codespace completed initialization;
- a documented procedure produced its stated result.

Do not create evidence records for incidental prose that cannot change the
outcome conclusion.

## Capture evidence

Use this shape for every material claim:

```text
Material claim:
Environment:
Why representative:
Implementation SHA:
Action performed:
Expected result:
Observed result:
Artifact:
Artifact type:
Redaction:
Retention:
Evidence reuse:
Result: pass | fail | blocked
```

Preferred artifacts, in order of auditability:

1. Machine-generated API output scoped to the relevant fields.
2. Real-trigger workflow or deployment run URL with critical log excerpts.
3. Redacted command transcript with command, exit status, and result.
4. Representative request/response or application interaction record.
5. Screenshot when no safer machine-readable export exists.
6. Rendered-document or reader checklist result for documentation outcomes.

A green build or deployment proves only that the build or deployment completed.
Exercise and record the affected user's action separately.

## Bind evidence to code

Record the implementation SHA used by the environment. If evidence comes from
an earlier SHA, state:

- which later paths changed;
- why none affect the material claim;
- whether trigger, permissions, configuration, and runtime stayed unchanged;
- the later SHA for which evidence is being reused.

If those conditions cannot be established, rerun the outcome validation.
For earlier-SHA evidence, format the field as `Paths: <later path analysis>;
Conditions: <trigger, permissions, configuration, and runtime analysis>` so
automation can distinguish the required analysis from vague reuse prose.

## Redact safely

Never publish secret values, tokens, personal data, production-sensitive data,
or raw environment dumps. Query allowlisted metadata fields and redact before
attaching an artifact. Prefer synthetic non-production values.

Record what was removed in `Redaction:` without revealing it. Run targeted
secret scanning over textual artifacts before publication when available.

## Retain evidence

Critical evidence must remain embedded in or linked from the issue or PR for
the PR lifetime. If a full artifact is authenticated or expires:

- place the material excerpt in the PR or linked issue;
- disclose authentication and expiration in `Retention:`;
- keep the disposable resource until capture succeeds;
- record a stable resource or run locator when safe.

Do not commit one-time logs or screenshots to the product branch solely for
evidence. Use GitHub comments, attachments, run artifacts, or provider locators,
with critical redacted excerpts retained in the review record.

## Review

Automation may verify required fields, SHA form, artifact presence, and
retention declarations. A reviewer must still decide whether:

- the claim is material;
- the environment preserves its load-bearing conditions;
- the action actually exercises the user outcome;
- the artifact supports the observed result;
- redaction and retention are appropriate.

If the environment or evidence does not support the conclusion, mark the result
`blocked` or `fail`; do not substitute supporting CI evidence.
