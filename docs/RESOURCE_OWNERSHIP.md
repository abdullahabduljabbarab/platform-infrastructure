# Resource Ownership

Every resource in the `ledger-api-507618` project has exactly one owning
repository. This charter exists to stop the drift where one repo creates a shared
resource, a second assumes it exists, and a third re-declares it. One owner
defines a resource's lifecycle; everyone else references it (a Terraform data
source, or a documented dependency).

## Ownership

| Resource | Owner |
|----------|-------|
| Workload Identity pool + provider (`github-actions` / `github`) | **platform-infrastructure** |
| Shared Pub/Sub topics (`transaction-events`, `payment-events`, `risk-events`) | **platform-infrastructure** |
| Project API enablement and project-level IAM that is platform-wide | **platform-infrastructure** |
| Cloud SQL instance (`ledger-db`) | ledger-api (referenced by others as a data source) |
| `ledger` database and schema | ledger-api |
| `payments` database and schema | payment-orchestrator |
| `risk` database and schema | risk-engine |
| `notify` database and schema | notification-service |
| Ledger / orchestrator / risk / notification runtime secrets | the respective service |
| Payment-events / risk-events push subscriptions into risk and notification | the consuming service |
| Notification's subscriptions and dead-letter | notification-service |
| Analytics BigQuery dataset (`analytics`), its subscriptions and dead-letter | analytics-service |
| Analytics refresh Cloud Run Job, its Cloud Scheduler schedule and scheduler identity | analytics-service |
| Cloud Scheduler API enablement (project-level) | **platform-infrastructure** |
| Each service's Cloud Run service, Artifact Registry repo, deploy SA and runtime SA | the respective service |

## Rules

- A resource's **lifecycle** (create, update, destroy) is defined only in its
  owner. Other repositories reference it, never redefine it.
- The shared Workload Identity **pool and provider** are owned here. Each service
  repo contributes only its own repo-scoped deploy service account and the
  binding that lets its repository impersonate it; it does not recreate the pool.
  Until this repo adopts the pool into Terraform state, service repos that
  previously declared it should reference it instead (a data source or a name
  composed from the project number).
- The Cloud SQL **instance** stays owned by ledger-api and is referenced by the
  other services (and by this repo) as a data source, not adopted here, to avoid
  drift on a heavily-defaulted resource.

## Deploy identities

| Repository | Deploy service account | Auth |
|------------|------------------------|------|
| ledger-api | `ledger-deploy` | Workload Identity Federation |
| payment-orchestrator | `orchestrator-deploy` | Workload Identity Federation |
| risk-engine | `risk-engine-deploy` | Workload Identity Federation |
| notification-service | `notification-service-deploy` | Workload Identity Federation |
| analytics-service | `analytics-service-deploy` | Workload Identity Federation |
| platform-infrastructure | none unless CI performs authenticated Terraform | manual/reviewed apply |

## Runtime identity audit

Deploy identity is fully federated. Runtime identities are recorded here; moving
services from the default compute service account to dedicated runtime identities
(as analytics already did) is hardening backlog, not part of this migration,
unless a specific identity is found over-privileged.

| Service | Runtime identity |
|---------|------------------|
| ledger-api | default compute SA |
| payment-orchestrator | default compute SA |
| risk-engine | default compute SA |
| notification-service | default compute SA |
| analytics-service | `analytics-service-runtime` (dedicated, dataset-scoped) |
