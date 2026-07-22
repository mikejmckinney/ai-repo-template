# Session: 2026-07-22 - main - OAuth routing and cache safety

**Status**: done
**Issue/PR**: [#503](https://github.com/mikejmckinney/ai-repo-template/issues/503) / [#504](https://github.com/mikejmckinney/ai-repo-template/pull/504)
**Started**: 2026-07-21T19:29:17Z

## What Was Accomplished

- Codespaces cleanup must remain dry-run by default, preserve agent state, and
  skip active uv runtimes.
- Hosted Sol access uses an access-only OAuth bundle. The real refresh token is
  never uploaded; stale or invalid content degrades to Kimi and then the normal
  provider cascade.

## What Shipped

- Every fix provider runs in a disposable worktree, and only a credential-free
  verified patch can be promoted.

## Harder Than Expected

- Workflow credentials need transitive runtime audit coverage; the same change
  patched `fast-uri` before merge.

## Generalizable Lessons

- Credential-bearing workflow changes require dependency-audit evidence in
  addition to behavior tests.

## Files Modified

- Cache cleanup, OAuth synchronization, provider routing, and runtime lock files.

## Open Items / Next

- None. Merge: [`04df21b`](https://github.com/mikejmckinney/ai-repo-template/commit/04df21b5d6be69be26fec5b19560b43bdba653af).
