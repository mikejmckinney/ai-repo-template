<#
.SYNOPSIS
    Set the Container Apps environment variables that Aspire "limited mode" leaves unpopulated.

.DESCRIPTION
    When Aspire runs in "limited mode", `azd provision` creates the Azure resources
    (Container Registry, Managed Identity, Container Apps Environment) but does NOT populate the
    env vars that `azd deploy` needs to reference them. This script fills that gap.

    Run it AFTER `azd provision` but BEFORE `azd deploy`.

    The script only sets a variable if it is currently missing, and prints what it did so the
    result can be understood without re-inspecting `azd env get-values`. Missing
    values are resolved only when the resource group contains exactly one registry
    and exactly one user-assigned managed identity.

.PARAMETER Environment
    Optional azd environment name (forwarded to `azd env` calls).
    Defaults to the current/default azd environment.

.EXAMPLE
    ./set-aspire-aca-env.ps1

.EXAMPLE
    ./set-aspire-aca-env.ps1 -Environment my-azd-env
#>

param(
    [string]$Environment
)

# Shared `-e <name>` argument list for azd calls (empty when no env name given).
$azdEnvArgs = @()
if ($Environment) {
    $azdEnvArgs = @('-e', $Environment)
}

# Capture azd environment values and verify the call succeeded. PowerShell does not treat a
# native command's non-zero exit code as a terminating error, so check $LASTEXITCODE explicitly
# rather than relying on $ErrorActionPreference.
$azdOutput = azd env get-values @azdEnvArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "'azd env get-values' failed with exit code $LASTEXITCODE. Run 'azd provision' before this script so the azd environment is available."
    exit 1
}

# Load azd environment values into a hashtable.
$azdValues = @{}
foreach ($line in $azdOutput) {
    if (-not $line) { continue }
    $name, $value = $line.Split('=', 2)
    $azdValues[$name] = $value.Trim('"')
}

$rgName = $azdValues['AZURE_RESOURCE_GROUP']
if (-not $rgName) {
    Write-Error "AZURE_RESOURCE_GROUP is not set in the azd environment. Run 'azd provision' before this script so the resource group is available."
    exit 1
}

function Set-EnvironmentValue {
    param(
        [string]$VarName,
        [string]$Value
    )
    azd env set @azdEnvArgs $VarName $Value
    Write-Host "${VarName}: set to $Value"
}

Write-Host "Resource group: $rgName"

$registryEndpoint = $azdValues['AZURE_CONTAINER_REGISTRY_ENDPOINT']
if ($registryEndpoint) {
    Write-Host "AZURE_CONTAINER_REGISTRY_ENDPOINT: already present ($registryEndpoint)"
} else {
    $registryJson = az acr list --resource-group $rgName --query '[].loginServer' -o json
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not list Azure Container Registries in resource group '$rgName'."
        exit 1
    }
    $registries = @($registryJson | ConvertFrom-Json)
    if ($registries.Count -ne 1) {
        Write-Error "Expected exactly one Azure Container Registry in resource group '$rgName'; found $($registries.Count). Set AZURE_CONTAINER_REGISTRY_ENDPOINT explicitly before rerunning this script."
        exit 1
    }
    Set-EnvironmentValue -VarName 'AZURE_CONTAINER_REGISTRY_ENDPOINT' -Value $registries[0]
}

$identityId = $azdValues['AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID']
$identityClientId = $azdValues['MANAGED_IDENTITY_CLIENT_ID']
if ($identityId -and $identityClientId) {
    Write-Host "AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID: already present ($identityId)"
    Write-Host "MANAGED_IDENTITY_CLIENT_ID: already present ($identityClientId)"
} else {
    $identityJson = az identity list --resource-group $rgName --query '[].{id:id,clientId:clientId}' -o json
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not list user-assigned managed identities in resource group '$rgName'."
        exit 1
    }
    $identities = @($identityJson | ConvertFrom-Json)
    if ($identities.Count -ne 1) {
        Write-Error "Expected exactly one user-assigned managed identity in resource group '$rgName'; found $($identities.Count). Set the managed identity azd environment values explicitly before rerunning this script."
        exit 1
    }
    $resolvedIdentity = $identities[0]
    if (-not $resolvedIdentity.id -or -not $resolvedIdentity.clientId) {
        Write-Error "The managed identity response did not include both id and clientId."
        exit 1
    }
    if ($identityId -and $identityId -ine $resolvedIdentity.id) {
        Write-Error "AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID does not match the discovered managed identity. Set both managed identity azd environment values explicitly before rerunning this script."
        exit 1
    }
    if ($identityClientId -and $identityClientId -ine $resolvedIdentity.clientId) {
        Write-Error "MANAGED_IDENTITY_CLIENT_ID does not match the discovered managed identity. Set both managed identity azd environment values explicitly before rerunning this script."
        exit 1
    }
    if (-not $identityId) {
        Set-EnvironmentValue -VarName 'AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID' -Value $resolvedIdentity.id
    } else {
        Write-Host "AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID: already present ($identityId)"
    }
    if (-not $identityClientId) {
        Set-EnvironmentValue -VarName 'MANAGED_IDENTITY_CLIENT_ID' -Value $resolvedIdentity.clientId
    } else {
        Write-Host "MANAGED_IDENTITY_CLIENT_ID: already present ($identityClientId)"
    }
}

Write-Host "Aspire Container Apps environment variables are ready for 'azd deploy'."
