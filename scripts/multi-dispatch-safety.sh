#!/usr/bin/env bash
# Safety library for the multi-issue dispatcher (#114).
#
# Sourced by .github/workflows/agent-multi-dispatch.yml AND by
# scripts/test-multi-dispatch-safety.sh. Exposes four pure-bash
# functions that can be unit-tested without touching the GitHub API.
#
# Functions
# ---------
#   extract_scope <issue_number>
#       Print the file-glob scope for an issue, one path per line.
#       Resolution order:
#         1. The first comment carrying an `<!-- architect-plan-files -->`
#            marker followed by a fenced code block (any author).
#         2. The first `role:<name>` label whose <name> matches a role
#            in scripts/parse-ownership-table.sh --list-roles. The role's
#            owned-path prefixes are emitted.
#         3. Nothing — emit `WARN: no scope detected for #N` to stderr
#            and exit 0 with empty stdout (caller treats as no overlap).
#       Mode reported on stderr as `MODE: architect|role-glob|none`.
#
#   extract_depends_on <issue_number>
#       Parse the issue body for `^Depends-on: #([0-9]+)$` lines and
#       emit each dependency issue number on its own line.
#
#   classify_overlap <fileset_a_file> <fileset_b_file>
#       Compare two newline-separated path lists; print one of
#       `hard` (any identical path), `soft` (any shared owned-path
#       prefix from agent_ownership.md), or `none`.
#
#   select_dispatchable <issue_list>
#       Walk the input issue numbers in order (= priority). For each
#       issue, refuse if (a) any depends-on target is not closed and
#       not already dispatched-this-run, (b) any depends-on chain
#       forms a cycle within the input set, or (c) its scope hard-
#       overlaps a previously-selected issue's scope. Emit one
#       `<issue>\t<verdict>\t<reason>` line per input issue (verdict
#       is `dispatch` or `refuse`).
#
# Test mode
# ---------
# When `MULTI_DISPATCH_TEST_MODE=1` is set, the GitHub-touching parts
# read from fixture files instead of `gh`:
#   FIXTURE_DIR/<N>.body         — issue body text
#   FIXTURE_DIR/<N>.labels       — one label per line
#   FIXTURE_DIR/<N>.comments     — one comment per record, each
#                                  preceded by `===COMMENT===` header
#   FIXTURE_DIR/<N>.state        — `open` or `closed`
# The tests set MULTI_DISPATCH_TEST_MODE=1 + FIXTURE_DIR=... before
# sourcing this file.
#
# See issue #114 and the implementation plan at
# https://github.com/mikejmckinney/ai-repo-template/issues/114.

set -euo pipefail

# ── Resolve repo paths regardless of CWD ──
_MDS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_MDS_REPO_ROOT="$(cd "$_MDS_LIB_DIR/.." && pwd)"
_MDS_OWNERSHIP_FILE="${MULTI_DISPATCH_OWNERSHIP_FILE:-$_MDS_REPO_ROOT/.context/rules/agent_ownership.md}"
_MDS_PARSE_OWNERSHIP="$_MDS_REPO_ROOT/scripts/parse-ownership-table.sh"

# ── Internal helpers ──

# Lazily compute the role -> prefix map. Caches in a module-level var.
_mds_role_prefixes=""
_mds_role_prefixes_loaded=""
_mds_load_role_prefixes() {
  if [[ -n "$_mds_role_prefixes_loaded" ]]; then
    return 0
  fi
  _mds_role_prefixes_loaded=1
  if [[ ! -f "$_MDS_OWNERSHIP_FILE" || ! -x "$_MDS_PARSE_OWNERSHIP" ]]; then
    _mds_role_prefixes=""
    return 0
  fi
  _mds_role_prefixes=$("$_MDS_PARSE_OWNERSHIP" < "$_MDS_OWNERSHIP_FILE" || true)
}

# Print the canonical role names this dispatcher recognizes (lowercased).
_mds_known_roles_lc() {
  if [[ ! -x "$_MDS_PARSE_OWNERSHIP" ]]; then
    return 0
  fi
  "$_MDS_PARSE_OWNERSHIP" --list-roles | tr '[:upper:]' '[:lower:]'
}

# Read an issue body (test-mode aware).
_mds_issue_body() {
  local n="$1"
  if [[ "${MULTI_DISPATCH_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.body" 2>/dev/null || true
  else
    gh issue view "$n" --json body --jq '.body' 2>/dev/null || true
  fi
}

# Read an issue's labels, one per line (test-mode aware).
_mds_issue_labels() {
  local n="$1"
  if [[ "${MULTI_DISPATCH_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.labels" 2>/dev/null || true
  else
    gh issue view "$n" --json labels --jq '.labels[].name' 2>/dev/null || true
  fi
}

# Read an issue's comment bodies concatenated, separated by ===COMMENT===
# headers (test-mode aware). Live mode uses --jq to emit the same shape.
_mds_issue_comments() {
  local n="$1"
  if [[ "${MULTI_DISPATCH_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.comments" 2>/dev/null || true
  else
    gh issue view "$n" --json comments \
      --jq '.comments[] | "===COMMENT===\n" + .body' 2>/dev/null || true
  fi
}

# Read an issue's state (test-mode aware). Returns `open` or `closed`.
_mds_issue_state() {
  local n="$1"
  if [[ "${MULTI_DISPATCH_TEST_MODE:-0}" == "1" ]]; then
    cat "${FIXTURE_DIR}/${n}.state" 2>/dev/null || echo "open"
  else
    gh issue view "$n" --json state --jq '.state' 2>/dev/null \
      | tr '[:upper:]' '[:lower:]' || echo "open"
  fi
}

# ── Public: extract_scope ──
#
# Resolution rules described in the file header. Mode is reported on
# stderr so callers can include it in the dispatch report; the file
# list itself is on stdout.
extract_scope() {
  local n="$1"
  local body comments labels

  # 1. Architect marker in any comment.
  comments="$(_mds_issue_comments "$n")"
  # Find the first ===COMMENT=== block that contains the marker, then
  # extract the first fenced code block from that comment.
  local plan_files
  plan_files=$(printf '%s\n' "$comments" | awk '
    BEGIN { in_target=0; in_fence=0; printed=0 }
    /^===COMMENT===$/ { in_target=0; in_fence=0; next }
    !printed && /<!-- architect-plan-files -->/ { in_target=1; next }
    in_target && /^```/ {
      if (in_fence) { printed=1; in_target=0; in_fence=0 } else { in_fence=1 }
      next
    }
    in_target && in_fence { print }
  ' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v '^$' || true)

  if [[ -n "$plan_files" ]]; then
    echo "MODE: architect" >&2
    printf '%s\n' "$plan_files"
    return 0
  fi

  # 2. role:<name> label fallback.
  labels="$(_mds_issue_labels "$n")"
  _mds_load_role_prefixes
  if [[ -n "$_mds_role_prefixes" ]]; then
    local known_lc
    known_lc="$(_mds_known_roles_lc)"
    local picked_role=""
    while IFS= read -r lbl; do
      [[ -z "$lbl" ]] && continue
      case "$lbl" in
        role:*)
          local rname="${lbl#role:}"
          rname="$(printf '%s' "$rname" | tr '[:upper:]' '[:lower:]')"
          if printf '%s\n' "$known_lc" | grep -qFx "$rname"; then
            picked_role="$rname"
            break
          fi
          ;;
      esac
    done <<< "$labels"
    if [[ -n "$picked_role" ]]; then
      # Emit prefixes for that role from the ownership map. Compare
      # case-insensitively against the role column. Filter out
      # English-prose rows (e.g. `colocated *.test.* / *.spec.* under
      # those paths`) by rejecting any prefix that contains internal
      # whitespace — real path globs never have spaces, prose always
      # does. This preserves glob metacharacters (`*`, `?`, `[`, `]`)
      # so future ownership rows with explicit globs aren't dropped
      # (gemini #7).
      local prefixes
      prefixes=$(printf '%s\n' "$_mds_role_prefixes" \
        | awk -F'\t' -v r="$picked_role" '
            { role=tolower($1); if (role==r) print $2 }
          ' | grep -v '[[:space:]]' | awk 'NF' | sort -u || true)
      if [[ -n "$prefixes" ]]; then
        echo "MODE: role-glob (role:$picked_role)" >&2
        printf '%s\n' "$prefixes"
        return 0
      fi
    fi
  fi

  # 3. None.
  echo "MODE: none (WARN: no scope detected for #$n — add a role:<name> label or post a comment with <!-- architect-plan-files --> followed by a fenced path list)" >&2
  return 0
}

# ── Public: extract_depends_on ──
#
# Strict line match on `Depends-on: #N` (case-insensitive). Multiple
# allowed, one number per emitted line. Whitespace either side of the
# number is tolerated.
extract_depends_on() {
  local n="$1"
  local body
  body="$(_mds_issue_body "$n")"
  # Require at least one space after the colon so `Depends-on:#N`
  # (no space) is rejected. Drop the end-of-line anchor so trailing
  # context like `Depends-on: #123 (backend)` is tolerated. The sed
  # below extracts the first `#NNN` token regardless of suffix.
  # `|| true` so set -e doesn't trip when there are zero matches.
  printf '%s\n' "$body" \
    | { grep -iE '^[[:space:]]*Depends-on:[[:space:]]+#[0-9]+' || true; } \
    | sed -E 's/^[[:space:]]*[Dd]epends-on:[[:space:]]+#([0-9]+).*/\1/' \
    | awk 'NF' \
    | sort -un
}

# ── Public: classify_overlap ──
#
# Two file-list arguments; emits exactly one of: hard | soft | none.
# Mirrors the classifier in agent-parallelism-report.yml.
classify_overlap() {
  local a="$1" b="$2"
  if [[ ! -s "$a" || ! -s "$b" ]]; then
    echo "none"
    return 0
  fi
  # Hard = any identical path.
  if comm -12 <(sort -u "$a") <(sort -u "$b") | grep -q .; then
    echo "hard"
    return 0
  fi
  # Soft = any owned-path prefix appears in BOTH.
  _mds_load_role_prefixes
  if [[ -z "$_mds_role_prefixes" ]]; then
    echo "none"
    return 0
  fi
  while IFS=$'\t' read -r _ prefix; do
    [[ -z "$prefix" ]] && continue
    local a_hit b_hit
    a_hit=$(awk -v p="$prefix" 'index($0, p"/")==1 || $0==p {print "y"; exit}' "$a")
    b_hit=$(awk -v p="$prefix" 'index($0, p"/")==1 || $0==p {print "y"; exit}' "$b")
    if [[ "$a_hit" == "y" && "$b_hit" == "y" ]]; then
      echo "soft"
      return 0
    fi
  done <<< "$_mds_role_prefixes"
  echo "none"
}

# ── Public: select_dispatchable ──
#
# Sequential first-fit. Walk the input list in order; dispatch each
# issue that doesn't conflict with anything already dispatched in
# this run. Emits TSV: `<issue>\t<verdict>\tdispatch_reason`.
#   verdict: dispatch | refuse
#   reason : human-readable string (see code for shapes)
#
# Conflict rules
#   - hard overlap with an already-selected issue → refuse.
#   - depends-on cycle within the input set → all cycle members refused.
#   - depends-on target outside the input set AND not closed → refuse.
#   - depends-on target inside the input set but earlier and refused
#     → refuse (transitive refusal).
#   - soft overlap (different files under the same owned-path prefix)
#     is permitted. NOTE: this only fires when at least one of the two
#     issues has an explicit architect file list. Two issues that both
#     fall back to the same `role:<name>` label resolve to identical
#     prefix lists, which classify_overlap reports as HARD overlap, so
#     the later issue is refused. To dispatch two same-role issues
#     together, post an architect-plan-files comment on at least one
#     of them naming the specific files it touches.
select_dispatchable() {
  # Collect inputs.
  local issues=("$@")
  local n=${#issues[@]}
  if (( n == 0 )); then
    return 0
  fi

  # Working dir for per-issue scope files.
  # Cleanup is handled at every exit path below (explicit `rm -rf` rather
  # than `trap RETURN` because this library is sourced by callers and a
  # RETURN trap would leak into and fire on every subsequent function
  # return in the caller's shell).
  local work
  work=$(mktemp -d)
  _mds_select_cleanup() { rm -rf "$work"; }

  # 1. Pre-compute scope for each input issue.
  local i
  for ((i=0; i<n; i++)); do
    extract_scope "${issues[i]}" > "$work/scope.${issues[i]}" 2> "$work/mode.${issues[i]}"
  done

  # 2. Pre-compute depends-on for each input issue (only deps that point
  #    inside the input set OR that are already closed are tractable;
  #    others trigger refusal).
  declare -A deps_of=()
  for ((i=0; i<n; i++)); do
    local iss="${issues[i]}"
    local d
    d=$(extract_depends_on "$iss" | tr '\n' ' ')
    deps_of["$iss"]="$d"
  done

  # 3. Cycle detection over the subgraph induced by input set.
  declare -A in_set=()
  for iss in "${issues[@]}"; do in_set["$iss"]=1; done
  local cycle_members=""
  cycle_members=$(_mds_find_cycles deps_of in_set "${issues[@]}")

  # 4. Sequential first-fit walk.
  declare -A selected=()      # issue -> 1
  local order=()              # selected, in input order

  for ((i=0; i<n; i++)); do
    local iss="${issues[i]}"

    # 4a. Cycle?
    if printf '%s\n' "$cycle_members" | grep -qx "$iss"; then
      printf '%s\trefuse\tDepends-on cycle within input set: %s\n' \
        "$iss" "$(printf '%s\n' "$cycle_members" | tr '\n' ' ' | sed 's/ $//')"
      continue
    fi

    # 4b. Dependency check.
    local dep_blocker=""
    for dep in ${deps_of["$iss"]}; do
      [[ -z "$dep" ]] && continue
      if [[ -n "${in_set[$dep]:-}" ]]; then
        # In-set dep: must be already selected (i.e. earlier in input).
        if [[ -z "${selected[$dep]:-}" ]]; then
          dep_blocker="depends on #$dep which is in this run but not yet dispatched (move #$dep earlier or drop the dependency)"
          break
        fi
      else
        # Out-of-set dep: must be closed.
        local st
        st=$(_mds_issue_state "$dep")
        if [[ "$st" != "closed" ]]; then
          dep_blocker="depends on #$dep which is not closed and not in this run"
          break
        fi
      fi
    done
    if [[ -n "$dep_blocker" ]]; then
      printf '%s\trefuse\t%s\n' "$iss" "$dep_blocker"
      continue
    fi

    # 4c. Hard overlap with anything already selected.
    local hard_with=""
    for prev in "${order[@]}"; do
      local cls
      cls=$(classify_overlap "$work/scope.$iss" "$work/scope.$prev")
      if [[ "$cls" == "hard" ]]; then
        hard_with="$prev"
        break
      fi
    done
    if [[ -n "$hard_with" ]]; then
      printf '%s\trefuse\thard overlap with already-dispatched #%s\n' "$iss" "$hard_with"
      continue
    fi

    # 4d. OK — dispatch.
    selected["$iss"]=1
    order+=("$iss")
    local mode
    mode=$(head -1 "$work/mode.$iss" 2>/dev/null | sed 's/^MODE: //' || echo "unknown")
    printf '%s\tdispatch\tscope=%s\n' "$iss" "$mode"
  done

  _mds_select_cleanup
}

# ── Internal: cycle detection ──
#
# Find nodes that participate in any cycle within the subgraph induced
# by `in_set`. Uses iterative DFS with white/gray/black coloring.
# Outputs cycle members one per line (sorted unique).
#
# Args: <deps_assoc_name> <in_set_assoc_name> <node...>
_mds_find_cycles() {
  local -n _deps="$1"
  local -n _inset="$2"
  shift 2
  local nodes=("$@")

  declare -A color=()           # 0=white, 1=gray, 2=black
  declare -A on_cycle=()
  local node u v stack=() iter=()

  for node in "${nodes[@]}"; do color["$node"]=0; done

  for node in "${nodes[@]}"; do
    [[ ${color["$node"]} -ne 0 ]] && continue
    # Iterative DFS.
    stack=("$node")
    color["$node"]=1
    # We track an explicit list of children-iterators by storing the
    # remaining deps of each frame in a parallel array.
    iter=("${_deps[$node]}")
    while (( ${#stack[@]} > 0 )); do
      u="${stack[-1]}"
      # Pop next dep from the iterator of the top frame.
      local rest="${iter[-1]}"
      if [[ -z "${rest// /}" ]]; then
        color["$u"]=2
        # `unset arr[-1]` removes the last element and decrements the
        # length, which is all the stack/iter logic needs (we only
        # ever read [-1]). No need to copy-rebuild the arrays.
        unset 'stack[-1]'
        unset 'iter[-1]'
        continue
      fi
      v="${rest%% *}"
      local rest2="${rest#"$v"}"
      rest2="${rest2# }"
      iter[-1]="$rest2"

      # Only consider deps inside the input set.
      [[ -z "${_inset[$v]:-}" ]] && continue

      case "${color[$v]:-0}" in
        0)
          color["$v"]=1
          stack+=("$v")
          iter+=("${_deps[$v]:-}")
          ;;
        1)
          # Back edge — cycle. Mark every gray frame from v..top.
          local mark=0
          for ((k=0; k<${#stack[@]}; k++)); do
            if [[ "${stack[k]}" == "$v" ]]; then mark=1; fi
            if (( mark )); then on_cycle["${stack[k]}"]=1; fi
          done
          ;;
        2)
          : # forward/cross edge — ignore.
          ;;
      esac
    done
  done

  for k in "${!on_cycle[@]}"; do printf '%s\n' "$k"; done | sort -u
}
