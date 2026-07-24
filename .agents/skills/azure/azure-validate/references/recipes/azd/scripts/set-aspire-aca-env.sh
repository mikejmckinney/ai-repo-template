#!/usr/bin/env bash
# Set the Container Apps environment variables that Aspire "limited mode" leaves unpopulated.
#
# When Aspire runs in "limited mode", `azd provision` creates the Azure resources
# (Container Registry, Managed Identity, Container Apps Environment) but does NOT populate the
# env vars that `azd deploy` needs to reference them. This script fills that gap.
#
# Run it AFTER `azd provision` but BEFORE `azd deploy`.
#
# USAGE:
#   ./set-aspire-aca-env.sh [-e <azd-env-name>]
#
#   -e, --environment   Optional azd environment name (forwarded to `azd env` calls).
#                       Defaults to the current/default azd environment.
#
# The script only sets a variable if it is currently missing, and prints what it did so the
# result can be understood without re-inspecting `azd env get-values`. Missing
# values are resolved only when the resource group contains exactly one registry
# and exactly one user-assigned managed identity.

set -e

AZD_ENV_NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    -e|--environment)
      AZD_ENV_NAME="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "USAGE: ./set-aspire-aca-env.sh [-e <azd-env-name>]" >&2
      exit 1
      ;;
  esac
done

# Build the shared `-e <name>` argument list for azd calls (empty when no env name given).
AZD_ENV_ARGS=()
if [ -n "$AZD_ENV_NAME" ]; then
  AZD_ENV_ARGS=(-e "$AZD_ENV_NAME")
fi

# Capture azd environment values via command substitution so `set -e` aborts if the
# `azd env get-values` call itself fails (rather than silently continuing with no values).
AZD_VALUES=$(azd env get-values "${AZD_ENV_ARGS[@]}")

# get_env_value <KEY> — print the (unquoted) value of KEY from AZD_VALUES, empty if absent.
# Uses only POSIX-friendly tools so it works on the widely-available Bash 3.2 (e.g. macOS).
get_env_value() {
  printf '%s\n' "$AZD_VALUES" \
    | grep "^$1=" \
    | head -n 1 \
    | sed -e "s/^$1=//" -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

RG_NAME=$(get_env_value AZURE_RESOURCE_GROUP)
if [ -z "$RG_NAME" ]; then
  echo "ERROR: AZURE_RESOURCE_GROUP is not set in the azd environment." >&2
  echo "Run 'azd provision' before this script so the resource group is available." >&2
  exit 1
fi

require_single_row() {
  rows="$1"
  resource_description="$2"
  nonempty_rows=$(printf '%s\n' "$rows" | sed '/^[[:space:]]*$/d')
  row_count=$(printf '%s\n' "$nonempty_rows" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
  if [ "$row_count" -ne 1 ]; then
    echo "ERROR: Expected exactly one $resource_description in resource group '$RG_NAME'; found $row_count." >&2
    echo "Set the corresponding azd environment values explicitly before rerunning this script." >&2
    return 1
  fi
  printf '%s\n' "$nonempty_rows"
}

set_env_value() {
  var_name="$1"
  value="$2"
  azd env set "${AZD_ENV_ARGS[@]}" "$var_name" "$value"
  echo "$var_name: set to $value"
}

equals_case_insensitive() {
  local left right
  left=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  right=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
  [ "$left" = "$right" ]
}

echo "Resource group: $RG_NAME"

registry_endpoint=$(get_env_value AZURE_CONTAINER_REGISTRY_ENDPOINT)
if [ -n "$registry_endpoint" ]; then
  echo "AZURE_CONTAINER_REGISTRY_ENDPOINT: already present ($registry_endpoint)"
else
  registry_rows=$(az acr list --resource-group "$RG_NAME" --query "[].loginServer" -o tsv)
  registry_endpoint=$(require_single_row "$registry_rows" "Azure Container Registry")
  set_env_value "AZURE_CONTAINER_REGISTRY_ENDPOINT" "$registry_endpoint"
fi

identity_id=$(get_env_value AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID)
identity_client_id=$(get_env_value MANAGED_IDENTITY_CLIENT_ID)
if [ -n "$identity_id" ] && [ -n "$identity_client_id" ]; then
  echo "AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID: already present ($identity_id)"
  echo "MANAGED_IDENTITY_CLIENT_ID: already present ($identity_client_id)"
else
  identity_rows=$(az identity list --resource-group "$RG_NAME" --query "[].[id,clientId]" -o tsv)
  identity_row=$(require_single_row "$identity_rows" "user-assigned managed identity")
  resolved_identity_id=$(printf '%s\n' "$identity_row" | cut -f1)
  resolved_identity_client_id=$(printf '%s\n' "$identity_row" | cut -f2)
  if [ -z "$resolved_identity_id" ] || [ -z "$resolved_identity_client_id" ]; then
    echo "ERROR: The managed identity response did not include both id and clientId." >&2
    exit 1
  fi
  if [ -n "$identity_id" ] && ! equals_case_insensitive "$identity_id" "$resolved_identity_id"; then
    echo "ERROR: AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID does not match the discovered managed identity." >&2
    echo "Set both managed identity azd environment values explicitly before rerunning this script." >&2
    exit 1
  fi
  if [ -n "$identity_client_id" ] && ! equals_case_insensitive "$identity_client_id" "$resolved_identity_client_id"; then
    echo "ERROR: MANAGED_IDENTITY_CLIENT_ID does not match the discovered managed identity." >&2
    echo "Set both managed identity azd environment values explicitly before rerunning this script." >&2
    exit 1
  fi
  if [ -z "$identity_id" ]; then
    set_env_value "AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID" "$resolved_identity_id"
  else
    echo "AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID: already present ($identity_id)"
  fi
  if [ -z "$identity_client_id" ]; then
    set_env_value "MANAGED_IDENTITY_CLIENT_ID" "$resolved_identity_client_id"
  else
    echo "MANAGED_IDENTITY_CLIENT_ID: already present ($identity_client_id)"
  fi
fi

echo "Aspire Container Apps environment variables are ready for 'azd deploy'."
