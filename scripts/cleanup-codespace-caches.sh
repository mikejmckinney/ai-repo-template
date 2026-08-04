#!/usr/bin/env bash

set -uo pipefail

apply=false
failures=0

usage() {
  cat <<'EOF'
Usage: scripts/cleanup-codespace-caches.sh [--apply]

Report reproducible package and build cache sizes. With --apply, clean npm,
npx, Bun, uv, pip, and Go caches. Active uv runtimes are never forced closed.

Options:
  --apply  Clean the reported caches.
  -h, --help  Show this help.
EOF
}

while (($# > 0)); do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'cleanup-codespace-caches: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

npm_root="${NPM_CONFIG_CACHE:-$HOME/.npm}"
npm_content="$npm_root/_cacache"
npm_npx="$npm_root/_npx"
bun_cache="$HOME/.bun/install/cache"
uv_cache="${UV_CACHE_DIR:-$HOME/.cache/uv}"
pip_cache="${PIP_CACHE_DIR:-$HOME/.cache/pip}"
go_cache="${GOCACHE:-$HOME/.cache/go-build}"

cache_bytes() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -s -B1 -- "$path" 2>/dev/null | cut -f1
  else
    printf '0\n'
  fi
}

available_bytes() {
  local available_kb=
  while read -r _ _ _ available _; do
    [[ "$available" =~ ^[0-9]+$ ]] && available_kb="$available"
  done < <(df -Pk "$HOME")
  if [[ "$available_kb" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$((available_kb * 1024))"
  else
    printf 'unknown\n'
  fi
}

report_cache() {
  local name="$1" path="$2"
  printf 'cache=%s bytes=%s path=%s\n' "$name" "$(cache_bytes "$path")" "$path"
}

run_cleanup() {
  local name="$1"
  shift
  if "$@"; then
    printf 'cache=%s status=cleaned\n' "$name"
  else
    printf 'cache=%s status=failed\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

printf 'mode=%s\n' "$([[ "$apply" == true ]] && printf apply || printf dry-run)"
printf 'available_before_bytes=%s\n' "$(available_bytes)"
report_cache npm-content "$npm_content"
report_cache npm-npx "$npm_npx"
report_cache bun "$bun_cache"
report_cache uv "$uv_cache"
report_cache pip "$pip_cache"
report_cache go "$go_cache"

if [[ "$apply" == false ]]; then
  printf 'result=dry-run; re-run with --apply to clean reported caches\n'
  exit 0
fi

if command -v npm >/dev/null 2>&1; then
  run_cleanup npm-content npm cache clean --force
  run_cleanup npm-npx npm cache npx rm --force
else
  printf 'cache=npm-content status=skipped reason=command-missing\n'
  printf 'cache=npm-npx status=skipped reason=command-missing\n'
fi

if rm -rf -- "$bun_cache"; then
  printf 'cache=bun status=cleaned\n'
else
  printf 'cache=bun status=failed\n' >&2
  failures=$((failures + 1))
fi

if pgrep -x uv >/dev/null 2>&1; then
  printf 'cache=uv status=skipped reason=active-process\n'
elif command -v uv >/dev/null 2>&1; then
  run_cleanup uv uv cache clean
else
  printf 'cache=uv status=skipped reason=command-missing\n'
fi

if command -v python3 >/dev/null 2>&1; then
  run_cleanup pip python3 -m pip cache purge
else
  printf 'cache=pip status=skipped reason=command-missing\n'
fi

if command -v go >/dev/null 2>&1; then
  run_cleanup go go clean -cache
else
  printf 'cache=go status=skipped reason=command-missing\n'
fi

printf 'available_after_bytes=%s\n' "$(available_bytes)"
if ((failures > 0)); then
  printf 'result=failed failures=%s\n' "$failures" >&2
  exit 1
fi
printf 'result=success\n'
