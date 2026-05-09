# scripts/checks/

Numbered verification modules sourced by `test.sh` (issue #255 Phase 4d).

## How it works

`test.sh` is a thin orchestrator (~95 lines). At runtime it:

1. Sources `scripts/lib/logging.sh` (color vars) and
   `scripts/lib/assertions.sh` (`PASS`/`FAIL`/`WARN` counters and the
   `pass`/`fail`/`warn` helpers).
2. `cd`s to the repo root.
3. Globs `scripts/checks/[0-9][0-9][0-9]-*.sh` in lexical order and
   `source`s each module. The 3-digit zero-padded prefix ensures the
   lexical sort matches the author's intended numeric order (mixed-width
   prefixes would sort `100` before `15`). Each module performs its
   checks and increments the shared counters via `pass`/`fail`/`warn`.
4. Prints the aggregate `Passed/Warnings/Failed` summary and exits.

Modules expect:

- CWD == repo root (orchestrator guarantees this).
- `$RED`/`$GREEN`/`$YELLOW`/`$NC` color vars to be set.
- `$PASS`/`$FAIL`/`$WARN` counters and `pass`/`fail`/`warn` functions to
  be defined.

No module should call `exit` — the orchestrator owns the exit code based
on the final `$FAIL` value.

## Naming

Files use a 3-digit zero-padded numeric `<NNN>-<concern>.sh` prefix. The
orchestrator's glob (`[0-9][0-9][0-9]-*.sh`) only matches that shape, and
a separate continuity check hard-fails if any `*.sh` file in
`scripts/checks/` lacks a numeric prefix (catches typos that would
otherwise silently skip a module).

The fixed-width prefix matters: bash globs sort lexically, so a 2-digit
`15-` would sort *after* a 3-digit `100-` and run the modules in the
wrong order. Always use three digits.

Numbers leave room for insertion: increments of 5 (010-, 015-, 020-,
025-, …) let new modules slot between existing ones without a renumber.

## Adding a new check

1. Pick a number that places the module at the right point in the run
   order (modules near the start are typically structural; modules near
   the end are typically deeper invariants).
2. Create `scripts/checks/<NNN>-<concern>.sh` (3-digit prefix). Start it
   with the standard header used by the existing modules.
3. Use `pass`/`fail`/`warn` for assertion outcomes. Do not redeclare
   counters or color vars.
4. Run `bash test.sh` to verify the new module is picked up and the
   summary count goes up.

## History

Pre-Phase-4d, `test.sh` was a 1,720-line monolith with all of these
checks inlined. Phase 4d split each `# --- <Section> ---` block into a
separate module. The split is shape-preserving — every assertion that
existed before the split exists after, in the same order, with the same
output bytes. `bash test.sh` still reports `365 / 1 / 0`.
