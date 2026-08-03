# Derived Repository Bootstrap

Use `scripts/create-derived-repo.sh` to create a remote repository from
`mikejmckinney/ai-repo-template`, copy allowlisted environment values into its
Actions secrets, and grant it access to matching selected Codespaces user
secrets. The script never reads values from another repository because GitHub
does not expose stored secret values.

## One-time credential

Create a dedicated classic personal access token named
`REPO_BOOTSTRAP_TOKEN`. It needs:

- `repo` to create private repositories and manage their Actions secrets;
- `codespace:secrets` (or the broader `codespace`) to inspect user-secret
  visibility and add the new repository to selected secrets.

Store this token once as both:

- an Actions secret on `mikejmckinney/ai-repo-template`, for manual workflow
  dispatch;
- a Codespaces user secret visible to `ai-repo-template`, for local use.

Do not grant it to generated repositories as an Actions or Codespaces secret.
The canonical manifest, `.config/derived-repo-secrets.json`, marks it as a
source-only credential, and tests reject workflow drift that would publish it.

The token has broad owner-level authority. Rotate it after suspected exposure,
and do not reuse the sandbox-only `SANDBOX_BOOTSTRAP_TOKEN` for this purpose.

## Codespaces usage

The current process environment is the only value source. Add the template
repository to each relevant Codespaces user secret before opening its
Codespace, or export an allowlisted value for the current command.

Preview without contacting GitHub:

```bash
scripts/create-derived-repo.sh --repo OWNER/PROJECT
```

Create the private repository and synchronize available values:

```bash
scripts/create-derived-repo.sh --repo OWNER/PROJECT --apply
```

Use `--visibility public` or `--visibility internal` explicitly when required.
Use `--reuse` to synchronize an existing repository. Without `--reuse`, an
existing repository is an error. When GitHub returns template ancestry, the
script rejects a repository generated from a different template; when ancestry
is unavailable, `--reuse` is the explicit authorization to proceed. Reuse reads
the repository's actual visibility from GitHub before evaluating Codespaces
coverage, regardless of the command's creation-visibility default.

## GitHub Actions usage

Run **Create derived repository** with `workflow_dispatch` from the `main`
branch of `mikejmckinney/ai-repo-template`. The workflow maps only manifest
approved Actions secret names into the script environment and checks out
trusted `main` without persisted credentials.

Workflow inputs are first mapped to step environment variables and are never
interpolated into the Bash program. The script then validates `OWNER/REPO` and
visibility values before mutation.

The normal workflow `GITHUB_TOKEN` cannot create repositories, write another
repository's Actions secrets, or manage user Codespaces secrets. The job uses
`REPO_BOOTSTRAP_TOKEN` for those operations. The workflow is identity-guarded
and cannot run from a repository generated from this template.

## Credential inventory

`.config/derived-repo-secrets.json` is the canonical inventory. Each entry
records the secret and environment-variable name, requirement level, Actions
and Codespaces destinations, and consuming workflows or tools.
Custom `--manifest` files are schema-validated and cannot route
`REPO_BOOTSTRAP_TOKEN` or GitHub authentication aliases to either destination
under another entry.

`OPENCODE_GITHUB_TOKEN` is a required destination workflow credential.
`SKILL_REFRESH_PR_TOKEN` is also required, but the manifest marks it
`bootstrap: false`: create the destination first, then create or expand a
fine-grained PAT to include that repository and add it as an Actions secret.
This preserves repository scope instead of requiring an all-repositories token.
Provider credentials and `SANDBOX_BOOTSTRAP_TOKEN` are optional capabilities.
When `OPENCODE_OPENAI_AUTH` is absent from the environment in a local run, the
script can delegate to `sync-opencode-oauth-secret.sh` to upload an access-only
bundle; it never uploads the real refresh token.

Entries marked `codespaces: true` and `actions: false` in the canonical manifest
are Codespaces-only credentials for interactive provider tooling. The manifest
is the authoritative name list; the bootstrap does not publish those entries as
Actions secrets. A missing user secret is reported and skipped.

`GH_PAT` is injected into every derived Codespace covered by its user-secret
visibility and becomes the interactive `gh`, Git, and sandbox bootstrap token.
Use a dedicated classic PAT limited to the required upstream and sandbox access,
with the `repo` and `workflow` scopes reported by
`scripts/codespace-post-start.sh`. Any broader scopes are available to code
running in each covered Codespace, so do not reuse an account-administration
token.

## Visibility behavior

For a Codespaces user secret with `selected` visibility, the script calls the
additive per-repository endpoint. It does not replace the selected repository
list, so prior grants remain intact. Secrets with `all` visibility need no
change. `private` visibility already covers a private default destination;
review visibility manually before using a public destination.

Dry-run remains offline: it reports the allowlisted names but does not query
GitHub to resolve whether each existing user secret is `selected`, `all`,
`private`, or missing. Those dispositions are resolved and printed only after
`--apply` authenticates with `REPO_BOOTSTRAP_TOKEN`. For selected secrets, the
script reports `repository granted` after the additive mutation; no mode previews
the resolved grant set before mutation.

If the bootstrap token lacks Codespaces scope, the script fails before creating
the repository. Missing required environment values also fail before any GitHub
operation. Optional absent values are reported by name and skipped. Secret
values are never printed.

The script does not create Codespaces user secrets or copy their values. It only
changes repository access for an existing secret whose visibility is `selected`.

## Recovery

- If creation succeeded but a later secret write failed, fix the named
  permission or missing value and rerun with `--reuse --apply`.
- To revoke an accidental selected-secret grant without deleting the repository,
  retrieve its numeric ID with `gh api repos/OWNER/PROJECT --jq .id`, then run
  `gh api --method DELETE
  user/codespaces/secrets/NAME/repositories/REPOSITORY_ID` for each affected
  secret. Reverting a manifest entry prevents future grants but does not revoke
  grants already applied.
- Deleting a temporary repository removes it from selected-secret access lists;
  verify both repository absence and grant removal after cleanup.
- If an unrelated repository already owns the destination name, choose another
  name. Do not use `--reuse` unless synchronizing that repository is intended.
- Run `scripts/setup.sh` inside a derived repository to report its current
  Actions-secret presence from the same canonical manifest.

## References

- [GitHub Codespaces user-secret REST API](https://docs.github.com/en/rest/codespaces/secrets)
- [GitHub Actions secret REST API](https://docs.github.com/en/rest/actions/secrets)
- [Issue #163](https://github.com/mikejmckinney/ai-repo-template/issues/163)
