# Platform Infrastructure

Shared, cross-cutting infrastructure for [ABS Financial Systems](https://github.com/abdullahabduljabbarab/abs-financial-systems). This repository owns the resources that belong to no single service, and the ecosystem's deployment and security posture: keyless CI/CD for every service, one authoritative definition for shared infrastructure, and explicit ownership of every resource.

It holds no application code. Its content is Terraform (with remote state), the resource-ownership charter, and the runbook for the migration that removed the last long-lived deployment keys from the platform.

## What this repository establishes

- **Zero long-lived CI/CD credentials.** Every service repository deploys through Workload Identity Federation, presenting a short-lived GitHub OIDC token that GCP exchanges to impersonate a repository-scoped deploy service account. No service-account JSON key is stored in any repository.
- **Shared infrastructure as code, with remote state.** The resources no one service owns, the Workload Identity pool and provider, the shared Pub/Sub topics, project-level API enablement and IAM, are defined here in Terraform against a GCS remote-state backend. Existing live resources are adopted incrementally with `terraform import` and zero-diff plans, never recreated, so the running platform is never disrupted.
- **Explicit resource ownership.** Every resource in the project has exactly one owning repository, recorded in [`RESOURCE_OWNERSHIP.md`](RESOURCE_OWNERSHIP.md), so no two repositories half-declare the same thing.

## The ecosystem this completes

| Service | Owns | Deploys via |
|---|---|---|
| ledger-api | authoritative double-entry money | keyless WIF |
| payment-orchestrator | payment lifecycle / saga | keyless WIF |
| risk-engine | deterministic decisioning | keyless WIF |
| notification-service | isolated downstream side effects | keyless WIF |
| analytics-service | event-sourced CQRS projections | keyless WIF |
| **platform-infrastructure** | **shared infra + platform security posture** | Terraform (remote state) |

The statement this earns: **five independently deployed services, zero long-lived CI cloud credentials, repository-scoped OIDC federation, explicit infrastructure ownership, and shared GCP infrastructure managed as code.**

## Contents

- [`RESOURCE_OWNERSHIP.md`](RESOURCE_OWNERSHIP.md) — one owner per resource.
- [`MIGRATION_RUNBOOK.md`](MIGRATION_RUNBOOK.md) — the step-by-step keyless-deploy migration for the ledger and orchestrator, and the Terraform adoption procedure.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — the shared-infrastructure and identity architecture.
- [`DECISIONS.md`](DECISIONS.md) — the decisions and their trade-offs as ADRs.
- [`SECURITY.md`](SECURITY.md), [`THREAT_MODEL.md`](THREAT_MODEL.md) — the platform security posture and its attack surface.
- [`PRODUCTION_LOG.md`](PRODUCTION_LOG.md) — the build and migration record.
- [`terraform/`](terraform/) — the shared infrastructure, with remote state.
