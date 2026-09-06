# Architecture

Platform-infrastructure owns the cross-cutting resources and the ecosystem's
deployment and security posture. It has no runtime; its architecture is an
identity model and an ownership model.

## Keyless deployment identity

Every service repository deploys to GCP without a stored credential:

```
GitHub Actions (repo: <owner>/<service>)
        │  mints a short-lived OIDC token
        ▼
Workload Identity Pool  github-actions   ─┐
  provider  github  (issuer github.com)   │ owned by platform-infrastructure
        │  attribute.repository == <owner>/<service>
        ▼
<service>-deploy service account          ─┘ (repo-scoped binding)
        │  impersonated for the length of one job
        ▼
gcloud run deploy ...   (no key anywhere)
```

The pool and provider are shared and owned here. Each service repo contributes
only its own `<service>-deploy` account and the binding that lets its repository,
and only its repository, impersonate it. The `attribute_condition` on the
provider restricts federation to the owner's repositories.

## Shared vs owned resources

The line the ownership charter draws:

```
                         platform-infrastructure owns
    ┌───────────────────────────────────────────────────────────┐
    │  Workload Identity pool + provider                         │
    │  shared topics: transaction-events, payment-events,        │
    │                 risk-events                                │
    │  project API enablement, platform-wide IAM                 │
    │  cross-service Cloud Scheduler wiring                      │
    └───────────────────────────────────────────────────────────┘

                         each service owns its own
    ┌───────────────────────────────────────────────────────────┐
    │  Cloud Run service, Artifact Registry repo                 │
    │  deploy SA + runtime SA                                    │
    │  its database/schema (or BigQuery dataset)                 │
    │  its subscriptions and dead-letter                        │
    └───────────────────────────────────────────────────────────┘

    ledger-db Cloud SQL instance: owned by ledger-api,
    referenced by others as a data source (not adopted here)
```

## Terraform and state

Shared infrastructure is defined in [`terraform/`](../terraform/) against a versioned
GCS remote-state backend (`gs://ledger-api-507618-tfstate`, prefix `platform`).
Existing live resources are adopted with Terraform 1.5 import blocks, reconciled
to a zero-diff plan, and never recreated. CI validates the configuration on every
push; `init`/`import`/`plan`/`apply` run from a Terraform-capable environment
(Cloud Shell), because the development machine's TLS-inspecting network prevents
the provider plugin from running, the same reason every service repo validates
Terraform in CI rather than locally.

## The end state

```
                        ABS Financial Systems

   ledger-api ──┐
   orchestrator ┤
   risk-engine  ┼─ five independently deployed services
   notification ┤     · zero long-lived CI cloud credentials
   analytics ───┘     · repository-scoped OIDC federation

   platform-infrastructure
        · one authoritative Workload Identity pool
        · shared infrastructure defined as code with remote state
        · explicit ownership: one owner per resource
```
