# Vendored Skill Supply Chain

This repository tracks every vendored external skill in `skills-lock.json` and
refreshes upstream repositories through one aggregate review branch. Repository-owned
skills are listed separately and never enter the external refresh path.

## Lock contract

`skills-lock.json` version 2 has two maps:

- `skills` contains externally sourced packages. Every record declares the
  GitHub source, immutable commit, upstream package path, installed destination,
  hash algorithm, and computed package hash. Packages with nested skills add a
  sorted `skillEntrypoints` list; it defaults to `SKILL.md` and must include the
  package root.
- `ownedSkills` contains repository-owned packages. These records declare only
  their installed destination and require manual freshness review.

Directory packages use `sha256-tree-v1`. The digest covers sorted relative file
paths, file bytes, executable versus non-executable mode, and sorted declared
exclusions. Git metadata is ignored. A `packageType: "file"` record hashes one
upstream file as the destination's `SKILL.md`.

`excludedPaths` is not a general ignore list. Every path must be sorted, unique,
present in the upstream package, and absent from the installed package. Changing
an exclusion changes the hash. Use exclusions only for audited generated
artifacts that should not be redistributed or executed.

`localOverride` records a temporary repository correction to an external
package when waiting for upstream would leave a verified defect active. It must
declare the tracking issue, reason, original upstream hash, and sorted modified
paths; `computedHash` remains the hash of the installed corrected package. Any
source containing a local override fails closed during `check` and `update`, so
an automated refresh cannot silently remove the correction. Remove the override
only after verifying that an upstream commit contains an equivalent fix, then
refresh normally. This is a bounded exception, not a general patch mechanism.

Validate the complete local inventory before and after any manual edit:

```bash
python3 scripts/skill-supply-chain.py validate-lock \
  --repo "$PWD" \
  --lock skills-lock.json
```

Validation rejects undeclared or missing skills, mutable refs, malformed
metadata, duplicate names, hash mismatches, unsafe destinations, symlinks, and
locally present excluded paths. A bundle record validates every declared nested
entrypoint while hashing and replacing its package tree once, avoiding
overlapping update destinations.

## Check and update a source

Check the default-branch head of one declared source without changing files:

```bash
python3 scripts/skill-supply-chain.py check \
  --repo "$PWD" \
  --lock skills-lock.json \
  --source render-oss/skills
```

The JSON result includes `changed`, `refChanged`, `packages`,
`refOnlyPackages`, old and new refs and hashes, and exclusions. `changed` is
true only when a declared package hash changes; an unrelated upstream commit
reports `refChanged: true` without opening a lock-only refresh PR. When one
package changes, unchanged sibling records appear under `refOnlyPackages`
because their refs advance with the source's atomic snapshot. Pin a known
commit with `--ref` when reproducing a review. For fixture or offline testing,
add both `--source-dir <path>` and `--ref <commit>`.

Update all declared packages from one source atomically:

```bash
python3 scripts/skill-supply-chain.py update \
  --repo "$PWD" \
  --lock skills-lock.json \
  --source render-oss/skills \
  --ref <reviewed-commit>
```

The updater fetches only declared package paths into a temporary bare Git
repository, disables hooks and credential helpers, rejects the `file` protocol,
extracts bounded regular files without following links, and never executes
downloaded content. It stages and verifies every changed package before replacing
destinations and writing the lock. A failed replacement restores package and
lock backups.

If a declared upstream package path disappears, both `check` and `update` fail
closed without deleting the vendored package or lock record. Treat this as a
possible upstream move: locate and review the replacement path. Update only `skillPath`,
then run `update --ref <reviewed-commit>` so the updater advances the ref and hash
atomically. Pre-editing `ref` can turn changed upstream bytes into a same-ref hash
mismatch. Package removal requires an explicit reviewed lock and destination change.

## Nightly review PRs

`.github/workflows/skill-refresh.yml` runs daily at 05:00 UTC and supports manual
dispatch. A manual run can set `source` to one declared `owner/repository` value;
an empty value checks every external source.

The workflow creates or updates one stable aggregate branch and review PR:
`automation/skill-refresh/all`. The PR starts as a draft and becomes ready only
after exact-head CI and lint both pass. A targeted manual dispatch starts from
that same branch, so it updates the existing aggregate review instead of creating
a second publication path. Sources are processed sequentially, and all skills
from one source still update atomically. A ref-only result stops before any
write. A material package change:

1. updates only that source's packages and lock records;
2. verifies source-level license evidence at the proposed immutable commit and
   validates any declared Markdown heading fragment before regenerating the
   pinned inventory from `sourceMetadata` in the lock;
3. scans refreshed package paths for credential signatures;
4. validates that source against the accumulated aggregate tree;
5. restores the source's prior packages, lock, and generated inventory if its
   update, secret scan, or validation fails, then continues to the next source;
6. validates the combined tree once after all selected sources have run;
7. opens or updates one draft PR with every successful source's refs, packages,
   hashes, generated license evidence, validation evidence, and failed-source
   summary;
8. releases the publishing runner, then invokes CI and lint as reusable jobs on
   the generated head;
9. runs a final job that correlates both results to the current PR head, marks the
   PR ready only when both pass, or leaves it draft with a failure comment.
   Same-repository pull request events created with `GITHUB_TOKEN` do not start
   new workflow runs, so those events are not the automated completion gate.

Before acquisition, the scheduled aggregate classifies any source containing a
declared `localOverride` as `blocked_by_local_override`. It reports that expected
block separately and does not call `check` or `update` for the source; direct
commands still fail closed. Updated and unchanged sources continue normally. Any
unexpected acquisition, update, secret-scan, or validation failure fails the
run, leaves that source unchanged, and prevents a new partial publication.

The publishing job has `contents: write` and `pull-requests: write` because it
must push the aggregate branch and maintain its draft PR. The final job uses the
required `SKILL_REFRESH_PR_TOKEN`, a fine-grained PAT restricted to the target
repository with `Contents: read` and `Pull requests: write`. GitHub rejects the
ready-for-review mutation from a job-scoped `GITHUB_TOKEN`; the PAT can perform
that mutation but cannot use the merge endpoint, which requires contents write.
The workflow has no auto-merge path. Generated commits cannot include workflow
or repository script changes; the downloaded packages are treated as data and
are never run by the publishing job.

Repository controls:

- Required setting: **Allow GitHub Actions to create and approve pull requests**.
- Required secret: `SKILL_REFRESH_PR_TOKEN`, provisioned manually after creating
  each repository because a repository-scoped token cannot authorize a repository
  before it exists.
- Merge gate: required code-owner approval on `main` through `CODEOWNERS`.

The Codespaces installer renders a missing downstream `CODEOWNERS` from the
workspace repository owner (`origin`, then `GITHUB_REPOSITORY_OWNER`). It skips
the file with a warning when no owner is available rather than copying the
template maintainer. For organization-owned repositories, replace the
organization handle with the user or team responsible for required approval.

The setting lets the job-scoped `GITHUB_TOKEN` open the draft. GitHub combines
pull request creation and review submission under that setting; it does not offer
a create-only switch. The finalizer uses `SKILL_REFRESH_PR_TOKEN` to mark the
validated draft ready. The separate code-owner gate prevents the creating
workflow from satisfying maintainer review. Never apply `auto-merge`.

### Human review checklist

- Compare the old and new upstream commits, including files outside the selected
  packages that explain the release or migration.
- Review every vendored byte and executable-mode change. Treat new scripts as
  untrusted even though automation does not execute them.
- Confirm package additions, removals, moves, and renames are intentional. The
  updater does not discover or adopt new paths or packages automatically.
- Recheck upstream license evidence and security notices at the proposed commit.
- Confirm exclusions still identify generated artifacts and do not hide
  substantive instructions or executable code.
- Require the secret scan, lock validation, focused tests, `./test.sh`, and CI to
  pass. Never enable auto-merge for these PRs.

### Recovery

- Rerun the workflow after diagnosing a source's first failing acquisition,
  secret-scan, or validation phase. Do not bypass the failed control.
- If upstream moved again during review, rerun the workflow; the stable aggregate
  branch and existing draft PR are updated instead of duplicated.
- If acquisition reports a missing upstream path, inspect the upstream tree for
  a move and update the lock only after reviewing the replacement package. Do
  not delete the local package or manually copy partial upstream state.
- If a local `update` is interrupted, run `validate-lock`, inspect `git diff`, and
  rerun against the intended immutable ref. Commit only a complete aggregate
  result composed of source-atomic updates.

## Add an external source or package

1. Establish the user outcome and select the smallest complete upstream package.
   Do not copy only `SKILL.md` when it depends on sibling scripts or references.
2. Verify the authoritative repository, license evidence, immutable commit,
   package boundary, generated artifacts, executable files, and absence of
   credentials.
3. Choose a unique metadata name and a destination under `.agents/skills`.
   Preserve provider parent directories for multi-skill providers.
4. Copy upstream bytes and executable modes without rewriting them. Use
   `packageType: "file"` only when the upstream package is genuinely one file.
5. Add the external lock record and source-level `sourceMetadata` license
   evidence, then calculate its hash with `scripts/skill-supply-chain.py hash`.
   Declare audited exclusions first. If
   the package contains nested skills, declare every relative `SKILL.md` path in
   sorted `skillEntrypoints` rather than creating overlapping package records.
6. Add or extend tests for package structure, provider nesting, discovery, and
   any new exclusion or package-type behavior.
7. Run lock validation, the refreshed-package secret scan, focused Bats tests,
   `python3 scripts/skill-supply-chain.py render-license-inventory --repo "$PWD"
   --lock skills-lock.json --check`, `./test.sh`, Markdown/link checks, and
   `git diff --check`.
8. Exercise the skill against a representative task. Static validation does not
   prove that the skill routes an agent to a correct user outcome.

For repository-owned guidance, add only an `ownedSkills` destination record and
an `Ownership and freshness` section in the skill. Assign a maintainer and
revalidate official links and version-sensitive claims when materially edited;
the nightly workflow will not update it.

## License inventory

The lock is canonical for package-to-source, package-to-commit, and source-level
license-evidence mappings. The generated inventory records the evidence reviewed
at each currently pinned commit.
Per maintainer decision, it links the exact upstream evidence rather than copying
license texts into this repository. Recheck the evidence whenever a source ref
changes; this table is not a substitute for complying with the linked terms.

<!-- generated:skill-license-inventory:begin -->
| Source | Packages | License | Pinned evidence |
|---|---:|---|---|
| `ChromeDevTools/chrome-devtools-mcp` | 3 | Apache-2.0 | [LICENSE](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/76fd2424984827802867672fcc8d0e0036f4a3af/LICENSE) |
| `SkyworkAI/Skywork-Skills` | 1 | MIT | [LICENSE](https://github.com/SkyworkAI/Skywork-Skills/blob/c8c6aeb742c3d6a2b728992142796702464b6fce/LICENSE) |
| `anthropics/skills` | 3 | Apache-2.0 | [frontend-design](https://github.com/anthropics/skills/blob/fa0fa64bdc967915dc8399e803be67759e1e62b8/skills/frontend-design/LICENSE.txt), [mcp-builder](https://github.com/anthropics/skills/blob/fa0fa64bdc967915dc8399e803be67759e1e62b8/skills/mcp-builder/LICENSE.txt), [skill-creator](https://github.com/anthropics/skills/blob/fa0fa64bdc967915dc8399e803be67759e1e62b8/skills/skill-creator/LICENSE.txt) |
| `aws/agent-toolkit-for-aws` | 19 | Apache-2.0 | [LICENSE](https://github.com/aws/agent-toolkit-for-aws/blob/b4416dddac9b6a0cc5412136e6dbf8f07ffdb31c/LICENSE) |
| `cloudflare/skills` | 2 | Apache-2.0 | [LICENSE](https://github.com/cloudflare/skills/blob/70215303d44a81a0db3219428f4825b604fc6061/LICENSE) |
| `elevenlabs/skills` | 2 | MIT | [LICENSE](https://github.com/elevenlabs/skills/blob/37c0f2a682a8953cb9f09b152a0e1624d234193e/LICENSE) |
| `microsoft/azure-skills` | 26 | MIT | [LICENSE](https://github.com/microsoft/azure-skills/blob/1b592c63641049ff33e4952c4021c63b4507f147/LICENSE) |
| `microsoft/playwright` | 1 | Apache-2.0 | [LICENSE](https://github.com/microsoft/playwright/blob/0edafe4baab7fd20122939d3cfe1acabd8ed84a9/LICENSE) |
| `netlify/context-and-tools` | 3 | MIT | [LICENSE](https://github.com/netlify/context-and-tools/blob/b4ac277e6795f90e6a1d163c001c0d7667ff9143/LICENSE) |
| `oracle/skills` | 3 | UPL-1.0 | [LICENSE](https://github.com/oracle/skills/blob/30e30dbcbf5f92f3564bc85f8fd59d32736adcd6/LICENSE.txt) |
| `phaserjs/phaser` | 28 | MIT | [LICENSE](https://github.com/phaserjs/phaser/blob/41be1e462bc600064e498cba370bfa8c5c055a22/LICENSE.md) |
| `railwayapp/railway-skills` | 1 | MIT | [LICENSE](https://github.com/railwayapp/railway-skills/blob/191601b4954527a87f4f004eaa355c8f30a855bf/LICENSE) |
| `render-oss/skills` | 21 | MIT | [LICENSE](https://github.com/render-oss/skills/blob/1b8496570748203351f628b2ae738805ac2c23d5/LICENSE) |
| `shadcn-ui/ui` | 1 | MIT | [LICENSE](https://github.com/shadcn-ui/ui/blob/4baadbc6517070ae8f8feb2c97037adc2b305544/LICENSE.md) |
| `supabase/agent-skills` | 2 | MIT | [LICENSE](https://github.com/supabase/agent-skills/blob/1ad9aaeb49caafd9e95c0a91116f71890eebbc53/LICENSE) |
| `vercel-labs/agent-skills` | 5 | MIT | [README license declaration](https://github.com/vercel-labs/agent-skills/blob/7c180d9044c9ae2b442b567aad4e42a28dd5ed62/README.md#license) |
| `vercel-labs/skills` | 1 | MIT | [README license declaration](https://github.com/vercel-labs/skills/blob/777599e1159e401b11ce4c8a57c20f09a8f1596e/README.md#license) |
<!-- generated:skill-license-inventory:end -->
