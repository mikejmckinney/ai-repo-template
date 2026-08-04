---
name: gcp
description: |
  Plan, deploy, and troubleshoot applications on Google Cloud using official
  documentation and standard gcloud, Terraform, Cloud Run, GKE, and Compute
  Engine workflows. Use for GCP architecture, authentication, deployment,
  operations, cost, reliability, and service selection. Do not use for another
  cloud provider or claim a repository-configured GCP MCP exists.
---

# Google Cloud

Use repository evidence and current Google Cloud documentation to select the
smallest operational surface that satisfies the workload. Do not invent project
IDs, regions, quotas, IAM roles, APIs, or current CLI flags.

## Establish context

Confirm only details that change the plan:

- target project and billing boundary;
- current account or workload identity;
- region, latency, residency, and availability requirements;
- workload protocol, state, background processing, and scaling behavior;
- existing deployment method, infrastructure code, and CI system;
- budget, recovery, observability, and compliance constraints.

Inspect the repository before selecting a service. Reuse existing Terraform,
Cloud Build, Docker, Kubernetes, or application configuration when it is valid.

## Select a runtime

- Prefer **Cloud Run** for stateless HTTP, WebSocket, worker, or event-driven
  containers when managed autoscaling and a request-oriented runtime fit.
- Prefer **GKE** when the workload requires Kubernetes APIs, custom controllers,
  multi-service scheduling, or cluster-level networking and policy controls.
- Prefer **Compute Engine** when the application requires VM or operating-system
  control, specialized images, or a runtime that does not fit managed services.
- Consider **Cloud Run functions** for bounded function-shaped handlers. Verify
  supported runtimes, triggers, limits, and deployment commands in current docs.
- Use managed databases, queues, caches, secrets, and observability services only
  after the application's state and consistency requirements are explicit.

Compare cost drivers, cold starts, connection lifetime, regional availability,
rollback behavior, and operational ownership before recommending a runtime.

## Authentication and safety

1. Use `gcloud auth login` for interactive CLI access and Application Default
   Credentials for local client-library workflows when appropriate.
2. Prefer user federation, workload identity, or attached service accounts over
   downloaded service-account keys.
3. Confirm the active account, project, region, and quota before mutations.
4. Start with read-only discovery. Show the planned command or infrastructure
   diff and obtain confirmation before destructive or cost-bearing actions.
5. Grant the narrowest roles needed to the deployer and runtime identities.
   Keep deployment authority separate from application runtime authority.

## Delivery workflow

1. Read dependency manifests, listening ports, health behavior, stateful paths,
   build artifacts, and current infrastructure code.
2. Confirm enabled APIs and prerequisite identities without enabling or creating
   resources unless requested.
3. Produce a service choice with rejected alternatives and load-bearing
   assumptions.
4. Prefer Terraform when the repository already manages infrastructure as code;
   preserve remote-state and provider conventions.
5. Otherwise, use current `gcloud` documentation and run a dry run, validation,
   or describe/list operation before deployment where supported.
6. Verify the deployed revision or workload, health endpoint, logs, metrics,
   rollback path, and expected project/region after a change.

Never treat a successful build as proof that the user journey works. Exercise a
non-destructive request or job path against the deployed environment.

## Troubleshooting

Classify failures before changing resources: authentication, authorization,
project selection, disabled API, quota, build, image, startup, health, network,
runtime, or application behavior. Capture the exact failing operation and
resource scope. Prefer logs and read-only resource descriptions, then make the
smallest reversible correction.

## Official sources

- [Google Cloud overview](https://cloud.google.com/docs/overview)
- [Authentication](https://cloud.google.com/docs/authentication)
- [Cloud Run](https://cloud.google.com/run/docs)
- [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/docs)
- [Compute Engine](https://cloud.google.com/compute/docs)
- [Terraform on Google Cloud](https://cloud.google.com/docs/terraform)
- [Well-Architected Framework](https://cloud.google.com/architecture/framework)

## Ownership and freshness

This is a repository-owned skill and is excluded from external refresh
automation. Revalidate service limits, supported runtimes, authentication
guidance, and command syntax against the linked official documentation whenever
behavior depends on current platform details or this skill is materially edited.
