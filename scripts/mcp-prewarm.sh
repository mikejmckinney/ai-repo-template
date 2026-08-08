#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
INVENTORY="${MCP_PREWARM_INVENTORY:-$REPO_ROOT/.config/mcp-inventory.json}"
RUNTIME_DIR="${MCP_PREWARM_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}/ai-repo-mcp}"
OPEN_DESIGN_SCRIPT="${MCP_PREWARM_OPEN_DESIGN_SCRIPT:-$REPO_ROOT/scripts/open-design-mcp.sh}"
JOBS="${MCP_PREWARM_JOBS:-2}"
TIMEOUT_SECONDS="${MCP_PREWARM_TIMEOUT_SECONDS:-120}"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

run_server=""
readiness_only=false

die() {
  printf 'mcp-prewarm: %s\n' "$*" >&2
  exit 2
}

usage() {
  cat <<'EOF'
Usage: scripts/mcp-prewarm.sh [--readiness-only]

Resolve pinned local MCP package dependencies from .config/mcp-inventory.json,
then verify the Open Design daemon health endpoint. The Codespaces lifecycle
uses this command before the first interactive OpenCode startup.

Options:
  --readiness-only  Skip package resolution and only verify Open Design.
  --help            Show this help.
EOF
}

while (($# > 0)); do
  case "$1" in
    --readiness-only)
      readiness_only=true
      shift
      ;;
    --run)
      (($# >= 2)) || die '--run requires a server name'
      run_server="$2"
      shift 2
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -f "$INVENTORY" ]] || die "inventory not found: $INVENTORY"

for required_command in jq sha256sum timeout xargs; do
  command -v "$required_command" >/dev/null 2>&1 \
    || die "required command is missing: $required_command"
done

if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || ((JOBS > 4)); then
  die 'MCP_PREWARM_JOBS must be an integer from 1 through 4'
fi
[[ "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] \
  || die 'MCP_PREWARM_TIMEOUT_SECONDS must be a positive integer'

umask 077
mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

safe_environment() {
  local server="$1"
  shift
  env -i \
    "HOME=$HOME" \
    "PATH=$PATH" \
    "TMPDIR=${TMPDIR:-/tmp}" \
    "LANG=${LANG:-C.UTF-8}" \
    "LC_ALL=${LC_ALL:-C.UTF-8}" \
    "NPM_CONFIG_CACHE=${NPM_CONFIG_CACHE:-$HOME/.npm}" \
    "UV_CACHE_DIR=${UV_CACHE_DIR:-$HOME/.cache/uv}" \
    "MCP_PREWARM_SERVER=$server" \
    "$@"
}

run_server_prewarm() {
  local server="$1" kind package python required_command started elapsed status
  local -a command=()
  local -a with_packages=()

  kind="$(jq -r --arg server "$server" '.servers[$server].prewarm.kind // empty' "$INVENTORY")"
  [[ -n "$kind" ]] || {
    printf 'mcp-prewarm: server=%s status=failed reason=missing-prewarm-metadata\n' "$server" >&2
    return 1
  }

  while IFS= read -r required_command; do
    [[ -n "$required_command" ]] || continue
    if ! command -v "$required_command" >/dev/null 2>&1; then
      printf 'mcp-prewarm: missing required command %s for %s\n' \
        "$required_command" "$server" >&2
      return 1
    fi
  done < <(jq -r --arg server "$server" \
    '.servers[$server].prewarm.required_commands[]? // empty' "$INVENTORY")

  case "$kind" in
    npx)
      package="$(jq -r --arg server "$server" '.servers[$server].prewarm.package // empty' "$INVENTORY")"
      [[ -n "$package" ]] || {
        printf 'mcp-prewarm: server=%s status=failed reason=missing-package\n' "$server" >&2
        return 1
      }
      command=(npx --yes --package "$package" -- node --version)
      ;;
    uvx)
      package="$(jq -r --arg server "$server" '.servers[$server].prewarm.package // empty' "$INVENTORY")"
      python="$(jq -r --arg server "$server" '.servers[$server].prewarm.python // empty' "$INVENTORY")"
      [[ -n "$package" ]] || {
        printf 'mcp-prewarm: server=%s status=failed reason=missing-package\n' "$server" >&2
        return 1
      }
      command=(uvx)
      [[ -n "$python" ]] && command+=(--python "$python")
      command+=(--from "$package")
      mapfile -t with_packages < <(jq -r --arg server "$server" \
        '.servers[$server].prewarm.with[]? // empty' "$INVENTORY")
      for package in "${with_packages[@]}"; do
        command+=(--with "$package")
      done
      command+=(python -c 'pass')
      ;;
    *)
      printf 'mcp-prewarm: server=%s status=failed reason=unsupported-kind-%s\n' \
        "$server" "$kind" >&2
      return 1
      ;;
  esac

  started=$SECONDS
  if safe_environment "$server" timeout --signal=TERM --kill-after=5 \
    "${TIMEOUT_SECONDS}s" "${command[@]}" >/dev/null 2>&1; then
    elapsed=$((SECONDS - started))
    printf 'mcp-prewarm: server=%s status=prepared elapsed=%ss\n' "$server" "$elapsed"
    return 0
  else
    status=$?
  fi

  elapsed=$((SECONDS - started))
  printf 'mcp-prewarm: server=%s status=failed exit=%s elapsed=%ss\n' \
    "$server" "$status" "$elapsed" >&2
  return "$status"
}

open_design_ready() {
  local started elapsed status
  local -a environment=(
    env -i
    "HOME=$HOME"
    "PATH=$PATH"
    "TMPDIR=${TMPDIR:-/tmp}"
    "LANG=${LANG:-C.UTF-8}"
    "LC_ALL=${LC_ALL:-C.UTF-8}"
  )

  [[ -x "$OPEN_DESIGN_SCRIPT" ]] || {
    printf 'mcp-prewarm: Open Design readiness failed; launcher is missing or not executable: %s\n' \
      "$OPEN_DESIGN_SCRIPT" >&2
    return 1
  }

  [[ -n "${OPEN_DESIGN_HOME:-}" ]] && environment+=("OPEN_DESIGN_HOME=$OPEN_DESIGN_HOME")
  [[ -n "${OPEN_DESIGN_DAEMON_URL:-}" ]] \
    && environment+=("OPEN_DESIGN_DAEMON_URL=$OPEN_DESIGN_DAEMON_URL")
  [[ -n "${XDG_RUNTIME_DIR:-}" ]] && environment+=("XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR")

  started=$SECONDS
  if "${environment[@]}" timeout --signal=TERM --kill-after=5 \
    "${TIMEOUT_SECONDS}s" "$OPEN_DESIGN_SCRIPT" --daemon-only >/dev/null 2>&1; then
    elapsed=$((SECONDS - started))
    printf 'mcp-prewarm: server=open-design status=healthy elapsed=%ss\n' "$elapsed"
    return 0
  else
    status=$?
  fi

  elapsed=$((SECONDS - started))
  printf 'mcp-prewarm: Open Design readiness failed exit=%s elapsed=%ss; bridge was not started\n' \
    "$status" "$elapsed" >&2
  return "$status"
}

if [[ -n "$run_server" ]]; then
  run_server_prewarm "$run_server"
  exit $?
fi

if [[ "$readiness_only" == false ]]; then
  mapfile -t servers < <(jq -r \
    '.servers | to_entries[] | select(.value.prewarm.kind? != null and .value.prewarm.kind != "open-design") | .key' \
    "$INVENTORY")
  package_status=0
  if ((${#servers[@]} > 0)); then
    if printf '%s\n' "${servers[@]}" | xargs -r -P "$JOBS" -n 1 \
      "$SCRIPT_PATH" --run; then
      package_status=0
    else
      package_status=$?
    fi
  fi
  if ((package_status != 0)); then
    printf 'mcp-prewarm: package resolution failed status=%s; retry the prewarm command before starting OpenCode\n' \
      "$package_status" >&2
    exit 1
  fi
fi

open_design_kind="$(jq -r '.servers["open-design"].prewarm.kind // empty' "$INVENTORY")"
if [[ "$open_design_kind" == "open-design" ]]; then
  open_design_status=0
  if open_design_ready; then
    open_design_status=0
  else
    open_design_status=$?
  fi
  if ((open_design_status != 0)); then
    exit 1
  fi
else
  printf 'mcp-prewarm: server=open-design status=skipped reason=not-inventory\n'
fi

printf 'mcp-prewarm: complete\n'
