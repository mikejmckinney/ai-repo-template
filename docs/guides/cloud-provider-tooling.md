# Cloud Provider Tooling

Interactive agents can use account-connected AWS, Azure, OCI, and Render MCPs.
The GCP and Colyseus integrations are repository-owned skills without MCPs. All
account-connected cloud MCPs remain disabled in locked review and fix profiles.

Use a non-production account, subscription, compartment, project, or workspace
for smoke tests. Start with read-only discovery. Do not create, update, deploy, or
delete resources merely to prove connectivity.

## Integration matrix

| Provider | Interactive MCP | Skill coverage | Authentication |
|---|---|---|---|
| AWS | Managed regional AWS MCP through `mcp-proxy-for-aws@1.6.3` | Official deploy and Elastic Beanstalk packages | Standard AWS credential chain, `AWS_PROFILE`, `AWS_REGION` |
| Azure | `@azure/mcp@2.0.5` | Prepare, deploy, validate, diagnostics, cost, reliability | Azure CLI / `DefaultAzureCredential` |
| OCI | `oracle.oci-cloud-mcp-server@2.1.0`, disabled by default | OCI router and Functions deploy/troubleshoot | OCI config profile, `OCI_CONFIG_PROFILE` |
| Render | Hosted `https://mcp.render.com/mcp` | All 21 official Render packages | `RENDER_API_KEY` bearer token |
| GCP | Deferred | Repository-owned `gcp` skill | `gcloud` and Application Default Credentials |
| Colyseus | Deferred | Repository-owned `colyseus` skill | Project and hosting-provider specific |

`.opencode/opencode.json` is the OpenCode configuration. `.mcp.json` supplies the
same integrations to clients that use the generic MCP configuration format.
Restart the client after changing credentials or enabled state.

## AWS

Install `uv`/`uvx` and configure an AWS CLI profile. Prefer IAM Identity Center,
role assumption, or another short-lived credential provider over static access
keys. The MCP proxy signs requests using the normal AWS credential chain; secrets
stay outside repository configuration.

Set the profile and region before starting the client:

```bash
export AWS_PROFILE="<read-only-test-profile>"
export AWS_REGION="us-east-1"
aws sts get-caller-identity --profile "$AWS_PROFILE"
aws configure get region --profile "$AWS_PROFILE"
```

Replace `us-east-1` with the region containing the test resources. The region
selects both the AWS MCP endpoint and request-signing region. Grant only the read
actions needed for the smoke-test service plus identity lookup; do not attach
broad administrator policy for MCP access.

### AWS smoke test

1. Confirm `aws sts get-caller-identity` returns the intended account and role.
2. Ask the AWS MCP to identify the caller and list or describe one resource type
   the role can read in `AWS_REGION`.
3. Confirm the response names the expected account and region and performs no
   mutation.
4. Let the federated session expire or revoke it after testing. Reauthenticate if
   the MCP reports an expired token; do not replace it with a long-lived key.

See [AWS MCP Server](https://docs.aws.amazon.com/aws-mcp/latest/userguide/what-is-aws-mcp.html)
and [AWS CLI profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

## Azure

Install Node.js/npm and Azure CLI, then authenticate interactively. Select the
intended cloud before login when using a sovereign cloud, and verify the active
tenant and subscription before starting the MCP:

```bash
az cloud show --query name --output tsv
az login
az account show \
  --query '{tenant:tenantId,subscription:id,name:name}' \
  --output table
```

Use `az account set --subscription <id>` when the login exposes multiple
subscriptions. Grant a read-only role at the narrowest resource-group or
subscription scope that supports the smoke test. Add service-specific data-plane
permissions only when a required read cannot use management-plane metadata.

### Azure smoke test

1. Ask Azure MCP to show the active subscription.
2. List or describe one resource group or known test resource without changing
   it.
3. Confirm the tenant, subscription, cloud, and resource scope are expected.
4. Run `az logout` when the test identity should not remain cached. Re-run
   `az login` when Azure CLI or `DefaultAzureCredential` reports expiry.

See [Azure MCP Server](https://github.com/microsoft/mcp) and
[Azure CLI authentication](https://learn.microsoft.com/cli/azure/authenticate-azure-cli).

## OCI

### Reference-only status

The configured OCI Cloud MCP is Oracle's proof-of-concept/reference server, not
a production-hardened control plane. Keep it disabled for normal use. Install
`uv`/`uvx` with Python 3.13 available and configure a least-privilege OCI CLI
profile. Prefer session or instance-principal authentication where supported;
protect API signing keys outside the repository.

```bash
export OCI_CONFIG_PROFILE="<read-only-test-profile>"
oci iam region list --profile "$OCI_CONFIG_PROFILE"
```

OCI operations also require the correct tenancy, compartment, and region. Grant
only inspection permissions for the test compartment and resource types.

### OCI smoke test

1. Set `OCI_MCP_ENABLED=true` for generic MCP clients and change the OCI entry's
   `disabled` value to `false`. In OpenCode, temporarily change only the OCI
   entry's `enabled` value to `true`.
2. Ask the OCI MCP to report tenancy/region context and list or inspect one
   resource type in the test compartment.
3. Confirm no mutation occurred and the result is scoped to the expected profile.
4. Restore `.mcp.json` to `disabled: true`, `.opencode/opencode.json` to
   `enabled: false`, and unset `OCI_MCP_ENABLED` after the test.

Never normalize OCI into always-on startup merely because a smoke test passes.
See [OCI CLI configuration](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdkconfig.htm)
and the [OCI Cloud MCP reference](https://github.com/oracle/mcp/tree/main/oci-cloud-mcp-server).

## Render

Create a Render API key for a constrained test account where possible and expose
it only to the interactive process:

```bash
export RENDER_API_KEY="<test-account-api-key>"
```

A Render API key can access every workspace and service available to its owner.
It cannot be narrowed per workspace in this configuration, so do not reuse a
high-privilege production account merely for agent connectivity.

### Render smoke test

1. Use Render MCP to list accessible workspaces.
2. Select the expected test workspace and list or inspect one service.
3. Confirm the service belongs to the intended workspace and do not trigger a
   deploy, restart, environment update, or deletion.
4. Unset or revoke the key when the test is complete. Replace an expired or
   revoked key rather than persisting it in a dotfile committed to Git.

See [Render MCP Server](https://render.com/docs/mcp-server) and
[Render API keys](https://render.com/docs/api#1-create-an-api-key).

## GCP

No generic GCP MCP is configured. The broadly applicable Cloud Assist MCP is not
generally available, while a service-specific MCP would misrepresent repository
coverage. Use the repository-owned `gcp` skill with official documentation and
standard tooling.

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project "<test-project-id>"
gcloud config get-value project
gcloud auth list --filter=status:ACTIVE
```

Prefer workforce/workload identity or attached service accounts over downloaded
keys. Separate deployer and runtime identities and grant roles at the narrowest
project or resource scope. Confirm project and region before any mutation. For a
read-only smoke test, ask the agent to use the `gcp` skill to compare Cloud Run,
GKE, and Compute Engine for a stated workload, then verify current commands and
limits against linked Google Cloud documentation.

See [Google Cloud authentication](https://cloud.google.com/docs/authentication)
and [Application Default Credentials](https://cloud.google.com/docs/authentication/provide-credentials-adc).

## Colyseus

No Colyseus MCP is configured because there is no official general management
MCP or verified retrieval gap that justifies maintaining a custom server. The
repository-owned `colyseus` skill routes rooms, synchronized state, matchmaking,
testing, load testing, deployment, scalability, and Colyseus Cloud work to
current official sources.

For dogfood, invoke the skill in a disposable project to create one minimal room
for the installed Colyseus version and a passing `@colyseus/testing` test. Verify
server-authoritative state and message validation rather than only checking that
files were generated. Reconsider an MCP only if Colyseus publishes an official
integration or measured tasks repeatedly fail because the skill and official
documentation cannot supply required context.

See [Colyseus documentation](https://docs.colyseus.io/) and
[unit testing](https://docs.colyseus.io/tools/unit-testing).

## Locked CI boundary

`.github/agent-runtime/review.json` and `fix.json` replace AWS, Azure, and OCI
commands with disabled `false` launchers and disable Render. Do not pass provider
credentials into these workflows or enable their account-connected MCP entries.
Run `bats scripts/tests/provider-integrations.bats` after any provider config
change to verify parity, pins, opt-in state, and locked-profile isolation.
