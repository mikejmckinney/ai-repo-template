# ADR-033: Derived Repository Credential Bootstrap

## Status

Accepted

## Date

2026-07-23

## Context

Repositories generated from `ai-repo-template` do not inherit repository
Actions secrets or selected Codespaces user-secret grants. GitHub exposes secret
names and visibility but never stored values. Repeated manual creation, secret
entry, and visibility updates can leave generated repositories without the
credentials expected by their workflows. Issue
[#163](https://github.com/mikejmckinney/ai-repo-template/issues/163) tracks the
operator outcome.

The operation needs owner-level authority to create a repository, write its
Actions secrets, and modify user-level Codespaces visibility. A normal workflow
`GITHUB_TOKEN` cannot perform those cross-repository and user-level operations.

## Decision

We will use one manifest-driven, dry-run-first script for both Codespaces and a
guarded manual workflow:

- values come only from an explicit process-environment allowlist;
- a dedicated `REPO_BOOTSTRAP_TOKEN` authorizes GitHub mutations;
- the bootstrap token is never granted to destination Actions or Codespaces;
- selected Codespaces grants use the additive per-repository endpoint;
- repository creation is private by default and remote-only;
- existing repositories require explicit `--reuse`;
- the workflow runs only from trusted `main` in the template repository.

The canonical credential inventory is
`.config/derived-repo-secrets.json`. Workflows and setup checks consume or
validate that inventory rather than carrying independent lists.

The default Codespaces tool profile will also include the current `core` plus
agent CLI set. Explicit `core` remains minimal, while explicit `agents`
preserves its existing core-plus-agents behavior.

## Options Considered

### Copy values from the source repository

- **Pros**: Appears to require no separate value source.
- **Cons**: Impossible through GitHub APIs because secret values are not
  retrievable.

### Expose all environment and Codespaces secrets

- **Pros**: Requires no inventory maintenance.
- **Cons**: Unbounded credential exposure and no consumer-level audit trail.

### Use one allowlist and dedicated bootstrap token

- **Pros**: Testable, redacted, usable locally and in Actions, and limits
  destination exposure to named consumers.
- **Cons**: The bootstrap token remains broadly privileged and the explicit
  workflow mapping must stay synchronized with the manifest.

### Reuse `SANDBOX_BOOTSTRAP_TOKEN`

- **Pros**: Avoids one additional credential name.
- **Cons**: Broadens a sandbox-only token and defeats its documented
  least-privilege boundary.

## Consequences

### Positive

- One operation creates and credential-bootstraps a derived repository.
- Repeated synchronization is safe and does not replace prior Codespaces
  grants.
- Missing values and permissions are reported without exposing values.
- Local and workflow paths execute the same implementation.

### Negative

- `REPO_BOOTSTRAP_TOKEN` needs broad repository plus Codespaces-secret access.
- New workflow credentials require a manifest and workflow mapping update.
- A public destination may need manual Codespaces visibility changes when a
  user secret is private-only.

### Neutral

- The script cannot eliminate one-time creation and storage of the bootstrap
  PAT because GitHub does not provide a safe self-bootstrap token.

## Verification

- **V1 contract tests**: dry-run, required and optional values, creation,
  explicit reuse, template mismatch, redaction, permission failure, additive
  visibility, and profile compatibility.
- **V2 repository checks**: Bats, `test.sh`, actionlint, formatting, links, and
  exact-head CI/lint.
- **V3 sandbox outcome**: create or reuse a disposable generated repository,
  verify secret-name presence and additive visibility, then repeat safely.

## Implementation

- [x] Canonical credential manifest and script.
- [x] Guarded manual workflow.
- [x] Combined default tool profile.
- [x] Sandbox and exact-head evidence recorded in PR #520.

## References

- [Issue #163](https://github.com/mikejmckinney/ai-repo-template/issues/163)
- [PR #520](https://github.com/mikejmckinney/ai-repo-template/pull/520)
- [Codespaces secrets API](https://docs.github.com/en/rest/codespaces/secrets)
- [Actions secrets API](https://docs.github.com/en/rest/actions/secrets)
