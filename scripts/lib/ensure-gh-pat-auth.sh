#!/usr/bin/env bash
# scripts/lib/ensure-gh-pat-auth.sh — Codespaces GITHUB_TOKEN → user PAT upgrade.
#
# Sourced by scripts/setup/40-ensure-labels.sh, scripts/codespace-post-start.sh,
# and scripts/diag-sandbox.sh. Keep GH_PAT_PROBE_VARS in sync everywhere.
#
# After ensure_gh_pat_auth():
#   ENSURE_GH_PAT_AUTH_UPGRADED  — "true" when gh auth login --with-token succeeded
#   ENSURE_GH_PAT_AUTH_VAR       — PAT env var name used (e.g. GH_PAT), or empty
#   ENSURE_GH_PAT_AUTH_LIMITED   — "true" when Codespaces still uses GITHUB_TOKEN
#   ENSURE_GH_PAT_AUTH_VALUE     — PAT value when a probe var is set (empty otherwise)

# shellcheck disable=SC2034
GH_PAT_PROBE_VARS=(GH_PAT GH_TOKEN_PAT CODESPACES_GH_PAT GITHUB_PAT)

_gh_pat_probe_first_set() {
  local _var
  for _var in "${GH_PAT_PROBE_VARS[@]}"; do
    if [[ -n "${!_var:-}" ]]; then
      printf '%s\n' "$_var"
      return 0
    fi
  done
  return 1
}

_gh_pat_codespaces_injected_token() {
  [[ "${CODESPACES:-}" == "true" ]] \
    && command -v gh &>/dev/null \
    && gh auth status 2>&1 | grep -qE 'Logged in to github\.com.*\(GITHUB_TOKEN\)'
}

ensure_gh_pat_auth() {
  ENSURE_GH_PAT_AUTH_UPGRADED=false
  ENSURE_GH_PAT_AUTH_VAR=""
  ENSURE_GH_PAT_AUTH_LIMITED=false
  ENSURE_GH_PAT_AUTH_VALUE=""

  if ! command -v gh &>/dev/null || ! gh auth status &>/dev/null; then
    return 0
  fi

  if ! _gh_pat_codespaces_injected_token; then
    return 0
  fi

  ENSURE_GH_PAT_AUTH_LIMITED=true

  local _pat_var _pat_val
  if ! _pat_var="$(_gh_pat_probe_first_set)"; then
    return 0
  fi

  _pat_val="${!_pat_var}"
  ENSURE_GH_PAT_AUTH_VAR="$_pat_var"
  ENSURE_GH_PAT_AUTH_VALUE="$_pat_val"

  unset GITHUB_TOKEN
  if printf '%s' "$_pat_val" | gh auth login --with-token 2>/dev/null; then
    ENSURE_GH_PAT_AUTH_UPGRADED=true
    ENSURE_GH_PAT_AUTH_LIMITED=false
  fi

  unset _pat_var _pat_val
  return 0
}

apply_gh_pat_session_exports() {
  # Export GH_TOKEN / BOOTSTRAP_GH_TOKEN from the first available PAT probe var.
  local _pat_var _pat_val
  if ! _pat_var="$(_gh_pat_probe_first_set)"; then
    return 1
  fi
  _pat_val="${!_pat_var}"
  unset GITHUB_TOKEN
  export GH_TOKEN="$_pat_val"
  export BOOTSTRAP_GH_TOKEN="${BOOTSTRAP_GH_TOKEN:-$_pat_val}"
  unset _pat_var _pat_val
  return 0
}

install_codespace_shell_auth_hook() {
  # Persist PAT-over-GITHUB_TOKEN for new interactive shells in this Codespace.
  local _hook_dir _hook_file _marker _line
  _hook_dir="${HOME}/.config/ai-repo-template"
  _hook_file="${_hook_dir}/codespace-auth.sh"
  _marker='# ai-repo-template codespace-auth (auto-installed by codespace-post-start.sh)'

  if ! _gh_pat_probe_first_set >/dev/null; then
    return 0
  fi

  mkdir -p "$_hook_dir"
  cat >"$_hook_file" <<'EOF'
# ai-repo-template codespace-auth (auto-installed by codespace-post-start.sh)
# Prefer Codespaces user PAT over the injected GITHUB_TOKEN for gh/git to sandbox.
if [[ "${CODESPACES:-}" == "true" ]]; then
  for _gh_pat_var in GH_PAT GH_TOKEN_PAT CODESPACES_GH_PAT GITHUB_PAT; do
    if [[ -n "${!_gh_pat_var:-}" ]]; then
      unset GITHUB_TOKEN
      export GH_TOKEN="${!_gh_pat_var}"
      export BOOTSTRAP_GH_TOKEN="${BOOTSTRAP_GH_TOKEN:-${!_gh_pat_var}}"
      break
    fi
  done
  unset _gh_pat_var
fi
EOF

  for _rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
    [[ -f "$_rc" ]] || continue
    if grep -qF "$_marker" "$_rc" 2>/dev/null; then
      continue
    fi
    _line='[[ -f "$HOME/.config/ai-repo-template/codespace-auth.sh" ]] && source "$HOME/.config/ai-repo-template/codespace-auth.sh"  # ai-repo-template codespace-auth (auto-installed by codespace-post-start.sh)'
    printf '\n%s\n' "$_line" >>"$_rc"
  done
}
