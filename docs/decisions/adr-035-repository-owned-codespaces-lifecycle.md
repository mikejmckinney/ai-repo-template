# ADR-035: Repository-owned Codespaces lifecycle

## Status

Accepted

## Date

2026-07-29

## Context

`ai-repo-template` is primarily a GitHub template for new repositories, but its
automatic Codespaces setup previously depended on selecting this entire
repository as account-level dotfiles. GitHub cloned that repository into its
persisted dotfiles checkout, then root `install.sh` copied an allowlisted subset
into the actual workspace. A repository created from the template already
contains those files, so this duplicated storage and applied template behavior
to unrelated Codespaces.

Without selected dotfiles, Codespaces does not discover a workspace root
`install.sh` or `scripts/setup.sh`. Repository-owned Dev Container lifecycle
commands are inherited with the template and apply only to the repository that
declares them. Issue
[#542](https://github.com/mikejmckinney/ai-repo-template/issues/542) records the
affected maintainer outcome and migration scope.

`scripts/setup.sh` is not an environment-only hook. It can initialize project
configuration, install project dependencies, run a build, create repository
labels, inspect secret presence, and verify an adapted project. Running it on
container creation would conflate reusable environment setup with explicit
project initialization.

## Decision

The canonical Codespaces lifecycle will be owned by
`.devcontainer/devcontainer.json`:

- `postCreateCommand` runs `scripts/codespace-post-create.sh`, which delegates
  only to `scripts/install-codespace-tools.sh --profile default`;
- `postStartCommand` runs the existing non-fatal
  `scripts/codespace-post-start.sh` authentication and sandbox hook;
- VS Code extensions are declared under
  `customizations.vscode.extensions`; and
- `scripts/setup.sh` remains an explicit command after project adaptation.

Root `install.sh` is removed. Its tool installation, extension declaration, and
startup responsibilities are owned by the Dev Container lifecycle, while its
copy inventory duplicated files already inherited from the GitHub template.
Users who selected this repository as account-level Codespaces dotfiles must
disable that setting. Development environments outside Dev Containers invoke
`scripts/install-codespace-tools.sh` directly.

## Migration

1. In GitHub Codespaces settings, stop using `ai-repo-template` as the account
   dotfiles repository.
2. Create or rebuild the repository Codespace so GitHub reads the inherited
   `.devcontainer/devcontainer.json`.
3. Outside a Dev Container, install the pinned environment explicitly with
   `scripts/install-codespace-tools.sh --profile default`.

The removed root entrypoint no longer supports selectively copying this
template into unrelated repositories. Use GitHub template creation for the full
repository or copy explicitly selected files when adopting only part of the kit.

## Options Considered

### Continue using the template as account-level dotfiles

- **Pros**: Preserves the existing automatic script discovery with no new
  configuration.
- **Cons**: Clones the complete template separately, affects unrelated
  Codespaces, and duplicates files already inherited by derived repositories.

### Run project setup automatically from a Dev Container

- **Pros**: Produces a single apparent setup command for the environment and
  project.
- **Cons**: Runs project dependencies, builds, labels, secret checks, and
  verification before maintainers finish adapting the template.

### Use repository-owned lifecycle hooks and remove the duplicate entrypoint

- **Pros**: Scopes behavior to derived repositories, versions setup with each
  project, avoids a duplicate template clone, and leaves one lifecycle owner.
- **Cons**: Existing users must disable their account-level dotfiles selection
  before creating or rebuilding Codespaces from this template.

### Maintain a separate minimal dotfiles repository

- **Pros**: Remains appropriate for personal shell preferences across all
  Codespaces.
- **Cons**: Does not replace repository-specific lifecycle configuration and
  creates another maintained repository.

## Consequences

### Positive

- New template-derived repositories configure their Codespaces without an
  account-level `ai-repo-template` clone.
- Container creation, container startup, and project initialization have
  separate, testable responsibilities.
- Extension declarations and lifecycle commands travel with the repository.

### Negative

- Existing dotfiles users must disable that account setting; the repository no
  longer supplies a dotfiles-discovered root installer.
- Representative validation requires creating a fresh Codespace and may incur
  compute or storage cost.

### Neutral

- Personal dotfiles remain useful for user-specific shell configuration, but
  they are outside this repository's project bootstrap responsibility.
- The pinned tool manifest and installer remain the canonical implementation;
  this decision changes their lifecycle entrypoint rather than their profiles.

## Verification

- **V1 contract tests**: validate lifecycle commands, extension declarations,
  default-profile delegation, repeatability, explicit project setup, and removal
  of the legacy root entrypoint.
- **V2 repository checks**: run focused and full Bats, `test.sh`, JSON parsing,
  ShellCheck, formatting, Markdown links, generated-surface checks, and
  exact-head CI/lint.
- **V3 user outcome**: create a repository from the candidate template without
  selecting dotfiles, create and restart its Codespace, and retain redacted
  evidence that post-create and post-start ran while `scripts/setup.sh` did not.
  This potentially billable operation requires explicit approval.

## Implementation

- [x] Add the repository-owned Dev Container definition and creation hook.
- [x] Preserve the non-fatal startup hook and explicit project setup boundary.
- [x] Remove root `install.sh` and its duplicate copy-inventory contracts.
- [x] Update setup guidance and lifecycle contracts.
- [ ] Record approved fresh-Codespace outcome evidence in PR
  [#543](https://github.com/mikejmckinney/ai-repo-template/pull/543).

## References

- [Issue #542](https://github.com/mikejmckinney/ai-repo-template/issues/542)
- [PR #543](https://github.com/mikejmckinney/ai-repo-template/pull/543)
- [Development Container specification](https://containers.dev/implementors/json_reference/#lifecycle-scripts)
- [GitHub Codespaces dotfiles behavior](https://docs.github.com/en/codespaces/setting-your-user-preferences/personalizing-github-codespaces-for-your-account#dotfiles)
