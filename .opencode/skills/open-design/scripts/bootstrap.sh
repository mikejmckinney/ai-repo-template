#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

on_error() {
  local status=$?
  printf 'error: bootstrap command failed (status %d): %s\n' "$status" "$BASH_COMMAND" >&2
  exit "$status"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

expand_home() {
  local path="$1"
  case "$path" in
    \~)
      printf '%s\n' "$HOME"
      ;;
    \~/*)
      printf '%s\n' "$HOME/${path#\~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

load_lock() {
  local line key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *:* ]] || continue
    key="$(trim "${line%%:*}")"
    value="$(trim "${line#*:}")"
    case "$key" in
      repo) lock_repo="$value" ;;
      ref) lock_ref="$value" ;;
      commit) lock_commit="$value" ;;
      install_dir) lock_install_dir="$value" ;;
    esac
  done <"$lock_file"
}

trap on_error ERR

lock_file=""
install_dir_override=""
mcp_client=""
apply_mcp=false

while (($# > 0)); do
  case "$1" in
    --lock)
      (($# >= 2)) || die "--lock requires a path"
      lock_file="$2"
      shift 2
      ;;
    --install-dir)
      (($# >= 2)) || die "--install-dir requires a directory"
      install_dir_override="$2"
      shift 2
      ;;
    --mcp-client)
      (($# >= 2)) || die "--mcp-client requires a name"
      mcp_client="$2"
      shift 2
      ;;
    --apply-mcp)
      apply_mcp=true
      shift
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$lock_file" ]] || die "--lock PATH is required"
[[ -f "$lock_file" ]] || die "lock file not found: $lock_file"
if [[ "$apply_mcp" == true && -z "$mcp_client" ]]; then
  die "--apply-mcp requires --mcp-client NAME"
fi

lock_repo=""
lock_ref=""
lock_commit=""
lock_install_dir=""
load_lock

[[ -n "$lock_repo" ]] || die "lock key 'repo' is required"
[[ -n "$lock_ref" ]] || die "lock key 'ref' is required"
[[ -n "$lock_install_dir" ]] || die "lock key 'install_dir' is required"

install_dir="${install_dir_override:-$lock_install_dir}"
install_dir="$(expand_home "$install_dir")"

printf 'Open Design bootstrap\n'
printf '  repo:        %s\n' "$lock_repo"
printf '  ref:         %s\n' "$lock_ref"
printf '  commit:      %s\n' "$lock_commit"
printf '  install_dir: %s\n\n' "$install_dir"

mkdir -p "$(dirname "$install_dir")"
existing_checkout=false
if [[ -e "$install_dir/.git" ]]; then
  existing_checkout=true
else
  git clone "$lock_repo" "$install_dir"
fi

cd "$install_dir"
if [[ "$existing_checkout" == true ]]; then
  actual_origin="$(git remote get-url origin)"
  [[ "$actual_origin" == "$lock_repo" ]] \
    || die "existing checkout origin '$actual_origin' does not match lock repo '$lock_repo'"
  worktree_status="$(git status --porcelain)"
  [[ -z "$worktree_status" ]] \
    || die "existing checkout has uncommitted changes: $install_dir"
fi

git fetch --tags origin
git checkout "$lock_ref"
if [[ -n "$lock_commit" ]]; then
  git checkout "$lock_commit"
fi

if command -v corepack >/dev/null 2>&1; then
  corepack enable
fi

pnpm install
pnpm --filter @open-design/daemon build
pnpm exec od --help

if [[ -n "$mcp_client" ]]; then
  if [[ "$apply_mcp" == true ]]; then
    pnpm exec od mcp install "$mcp_client"
  else
    pnpm exec od mcp install "$mcp_client" --print
  fi
fi

printf '\nBootstrap complete.\n'
