#!/usr/bin/env bash
# Stage an exact upstream candidate on sandbox main, then restore it safely.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sandbox-candidate.sh stage --candidate SHA [--repo PATH] [--remote NAME]
  sandbox-candidate.sh status --candidate SHA --baseline SHA --backup-ref REF [--repo PATH] [--remote NAME]
  sandbox-candidate.sh restore --candidate SHA --baseline SHA --backup-ref REF [--repo PATH] [--remote NAME]
  sandbox-candidate.sh cleanup --baseline SHA --backup-ref REF [--repo PATH] [--remote NAME]

The candidate must be the current branch tip on origin. The target is always
the recognized sandbox sibling's refs/heads/main.
EOF
}

die() {
  local code="$1"
  shift
  printf 'sandbox-candidate: %s\n' "$*" >&2
  exit "$code"
}

remote_identity_from_url() {
  local url="${1%/}"
  local path
  case "$url" in
    *://*)
      path="${url#*://}"
      path="${path#*@}"
      path="${path#*/}"
      ;;
    *@*:*) path="${url#*:}" ;;
    *) path="$url" ;;
  esac
  printf '%s\n' "${path%.git}"
}

remote_ref_sha() {
  local remote="$1" ref="$2" line
  line="$(git -C "$repo" ls-remote --refs "$remote" "$ref")"
  [[ -n "$line" ]] || return 1
  printf '%s\n' "${line%%[[:space:]]*}"
}

validate_sha() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]] || die 2 "invalid full commit SHA: $1"
}

validate_backup_ref() {
  [[ "$1" =~ ^refs/tags/sandbox-candidate/[0-9a-f]{12}-[0-9a-f]{12}$ ]] \
    || die 2 "invalid backup ref: $1"
}

emit_state() {
  local state="$1" current="$2"
  jq -n \
    --arg state "$state" \
    --arg remote "$remote" \
    --arg branch main \
    --arg candidate "$candidate" \
    --arg baseline "$baseline" \
    --arg backupRef "$backup_ref" \
    --arg current "$current" \
    --arg sourceRef "$source_ref" \
    '{state:$state,remote:$remote,branch:$branch,candidate:$candidate,baseline:$baseline,backupRef:$backupRef,current:$current}
      + (if $sourceRef == "" then {} else {sourceRef:$sourceRef} end)'
}

[[ $# -gt 0 ]] || {
  usage >&2
  exit 2
}

command_name="$1"
shift
repo="."
remote="${SANDBOX_REMOTE:-sandbox}"
candidate=""
baseline=""
backup_ref=""
source_ref=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || die 2 "--repo requires a path"
      repo="$2"
      shift 2
      ;;
    --remote)
      [[ $# -ge 2 ]] || die 2 "--remote requires a name"
      remote="$2"
      shift 2
      ;;
    --candidate)
      [[ $# -ge 2 ]] || die 2 "--candidate requires a SHA"
      candidate="$2"
      shift 2
      ;;
    --baseline)
      [[ $# -ge 2 ]] || die 2 "--baseline requires a SHA"
      baseline="$2"
      shift 2
      ;;
    --backup-ref)
      [[ $# -ge 2 ]] || die 2 "--backup-ref requires a ref"
      backup_ref="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die 2 "unknown argument: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die 2 "git is required"
command -v jq >/dev/null 2>&1 || die 2 "jq is required"
repo="$(cd "$repo" && pwd)"
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die 2 "not a git worktree: $repo"

[[ "$remote" != origin ]] || die 2 "refusing upstream remote 'origin'"
origin_url="$(git -C "$repo" remote get-url origin 2>/dev/null)" \
  || die 2 "origin remote is required"
remote_url="$(git -C "$repo" remote get-url "$remote" 2>/dev/null)" \
  || die 2 "remote '$remote' is not configured"
[[ "$remote_url" != "$origin_url" ]] || die 2 "refusing remote with the upstream URL"

upstream_identity="$(remote_identity_from_url "$origin_url")"
sandbox_identity="$(remote_identity_from_url "$remote_url")"
expected_sandbox_identity="${SANDBOX_REPO_NAME:-${upstream_identity}-sandbox}"
expected_sandbox_identity="$(remote_identity_from_url "$expected_sandbox_identity")"
[[ "$sandbox_identity" == "$expected_sandbox_identity" ]] \
  || die 2 "remote '$remote' is not the sandbox sibling '${expected_sandbox_identity}'"

main_ref="refs/heads/main"

case "$command_name" in
  stage)
    [[ -n "$candidate" ]] || die 2 "stage requires --candidate"
    candidate="$(git -C "$repo" rev-parse --verify "${candidate}^{commit}" 2>/dev/null)" \
      || die 2 "candidate commit is unavailable: $candidate"
    validate_sha "$candidate"
    source_branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)" \
      || die 2 "stage requires an attached upstream branch"
    source_ref="refs/heads/${source_branch}"
    upstream_candidate="$(remote_ref_sha origin "$source_ref" || true)"
    [[ "$upstream_candidate" == "$candidate" ]] \
      || die 2 "candidate is not the upstream branch tip for $source_ref"
    baseline="$(remote_ref_sha "$remote" "$main_ref")" \
      || die 3 "sandbox main is missing"
    validate_sha "$baseline"
    [[ "$candidate" != "$baseline" ]] || die 2 "candidate already equals sandbox main"
    backup_ref="refs/tags/sandbox-candidate/${baseline:0:12}-${candidate:0:12}"

    existing_backup="$(remote_ref_sha "$remote" "$backup_ref" || true)"
    if [[ -n "$existing_backup" && "$existing_backup" != "$baseline" ]]; then
      die 3 "backup ref already points elsewhere: $backup_ref"
    fi
    if [[ -z "$existing_backup" ]]; then
      git -C "$repo" fetch --quiet --no-tags "$remote" "$main_ref"
      fetched_baseline="$(git -C "$repo" rev-parse FETCH_HEAD)"
      [[ "$fetched_baseline" == "$baseline" ]] \
        || die 3 "sandbox main changed while creating the backup"
      git -C "$repo" push --quiet "$remote" "FETCH_HEAD:$backup_ref"
    fi

    git -C "$repo" push --quiet \
      --force-with-lease="${main_ref}:${baseline}" \
      "$remote" "${candidate}:${main_ref}" \
      || die 3 "sandbox main changed before candidate staging"
    current="$(remote_ref_sha "$remote" "$main_ref")"
    [[ "$current" == "$candidate" ]] || die 3 "candidate staging verification failed"
    emit_state staged "$current"
    ;;
  status)
    [[ -n "$candidate" && -n "$baseline" && -n "$backup_ref" ]] \
      || die 2 "status requires --candidate, --baseline, and --backup-ref"
    validate_sha "$candidate"
    validate_sha "$baseline"
    validate_backup_ref "$backup_ref"
    current="$(remote_ref_sha "$remote" "$main_ref")" || die 3 "sandbox main is missing"
    backup_sha="$(remote_ref_sha "$remote" "$backup_ref" || true)"
    if [[ "$backup_sha" != "$baseline" ]]; then
      state=drift
    elif [[ "$current" == "$candidate" ]]; then
      state=staged
    elif [[ "$current" == "$baseline" ]]; then
      state=restored
    else
      state=drift
    fi
    emit_state "$state" "$current"
    [[ "$state" != drift ]] || exit 3
    ;;
  restore)
    [[ -n "$candidate" && -n "$baseline" && -n "$backup_ref" ]] \
      || die 2 "restore requires --candidate, --baseline, and --backup-ref"
    validate_sha "$candidate"
    validate_sha "$baseline"
    validate_backup_ref "$backup_ref"
    current="$(remote_ref_sha "$remote" "$main_ref")" || die 3 "sandbox main is missing"
    [[ "$current" == "$candidate" ]] \
      || die 3 "sandbox main drifted; expected staged candidate $candidate, found $current"
    backup_sha="$(remote_ref_sha "$remote" "$backup_ref" || true)"
    [[ "$backup_sha" == "$baseline" ]] || die 3 "backup ref does not contain the expected baseline"

    git -C "$repo" fetch --quiet --no-tags "$remote" "$backup_ref"
    fetched_baseline="$(git -C "$repo" rev-parse FETCH_HEAD)"
    [[ "$fetched_baseline" == "$baseline" ]] || die 3 "fetched backup does not match baseline"
    git -C "$repo" push --quiet \
      --force-with-lease="${main_ref}:${candidate}" \
      "$remote" "FETCH_HEAD:${main_ref}" \
      || die 3 "sandbox main changed before restoration"
    current="$(remote_ref_sha "$remote" "$main_ref")"
    [[ "$current" == "$baseline" ]] || die 3 "sandbox restoration verification failed"
    emit_state restored "$current"
    ;;
  cleanup)
    [[ -n "$baseline" && -n "$backup_ref" ]] \
      || die 2 "cleanup requires --baseline and --backup-ref"
    validate_sha "$baseline"
    validate_backup_ref "$backup_ref"
    candidate=""
    current="$(remote_ref_sha "$remote" "$main_ref")" || die 3 "sandbox main is missing"
    [[ "$current" == "$baseline" ]] \
      || die 3 "restore sandbox main before cleanup; expected $baseline, found $current"
    backup_sha="$(remote_ref_sha "$remote" "$backup_ref" || true)"
    [[ "$backup_sha" == "$baseline" ]] || die 3 "backup ref does not contain the expected baseline"
    git -C "$repo" push --quiet \
      --force-with-lease="${backup_ref}:${baseline}" \
      "$remote" ":${backup_ref}" \
      || die 3 "backup ref changed before cleanup"
    [[ -z "$(remote_ref_sha "$remote" "$backup_ref" || true)" ]] \
      || die 3 "backup cleanup verification failed"
    emit_state cleaned "$current"
    ;;
  *)
    usage >&2
    die 2 "unknown command: $command_name"
    ;;
esac
