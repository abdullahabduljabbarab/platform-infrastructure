# Architecture Decision Records

Decisions specific to the shared platform infrastructure.

## ADR-001: Keyless CI/CD for every service, no long-lived keys

**Status:** Accepted

**Context:** Three services (risk, notification, analytics) already deployed
through Workload Identity Federation, but the ledger and orchestrator still held a
long-lived `GCP_SA_KEY` JSON key in their GitHub secrets, the highest-frequency
cloud-credential leak vector.

**Decision:** Every service repository deploys through repository-scoped WIF: a
short-lived GitHub OIDC token exchanged for impersonation of a per-repo deploy
service account. No service-account key is stored in any repository. The migration
was done one service at a time, proving the keyless deploy green and the live
service healthy before deleting each key, and revoking the underlying GCP key
afterwards.

**Consequences:** The platform holds zero long-lived CI/CD cloud credentials, a
measurable, finished property. Each repo's blast radius is a repository-scoped
identity, not a portable key.

## ADR-002: Hybrid Terraform adoption, remote state, incremental import

**Status:** Accepted

**Context:** The ecosystem's Terraform had been a declarative record only,
provisioned by gcloud with no state anywhere. Shared infrastructure deserves a
single authoritative definition, but mass-importing a live project risks drift or
accidental mutation of heavily-defaulted resources.

**Decision:** A real GCS remote-state backend, but resources are adopted
incrementally with Terraform import blocks and reconciled to a zero-diff plan
before any apply, never recreated. The clearly platform-owned resources (the WIF
pool and provider, the shared Pub/Sub topics) are adopted first; the Cloud SQL
instance is deliberately left as a data source owned by the ledger, and
project-level IAM is left for a later careful pass.

**Consequences:** The truthful claim is "shared infrastructure is Terraform-managed
with remote state; existing resources were adopted incrementally using import and
zero-diff plans to avoid disrupting the live system", stronger than "Terraform
describes what I clicked", without the risk of a big-bang import.

## ADR-003: One owner per resource

**Status:** Accepted

**Context:** The WIF pool was created in the risk engine's Terraform, referenced by
notification and analytics, and about to be declared again here, three repos, one
resource.

**Decision:** Every resource has exactly one owning repository, recorded in
RESOURCE_OWNERSHIP.md. The owner defines the lifecycle; everyone else references it.
The WIF pool and provider and the shared topics are owned here; the risk engine's
Terraform was changed to reference the pool rather than create it.

**Consequences:** No two repositories fight over the same resource, and there is a
single place to answer "who owns this."

## ADR-004: Scope the migration to deploy identities; runtime is backlog

**Status:** Accepted

**Context:** The concrete security defect was the stored deploy keys. Services also
mostly run on the default compute service account rather than dedicated runtime
identities.

**Decision:** This work migrates deploy identities only. A runtime-identity audit
is recorded, but moving services off the default compute SA to dedicated runtime
identities (as analytics already did) is hardening backlog, not part of this
migration, unless a specific identity is found over-privileged.

**Consequences:** The finished, measurable property (zero stored deploy keys) is
delivered cleanly, without an open-ended IAM refactor across every service.

## ADR-005: Do not create an App Engine app for Cloud Scheduler

**Status:** Accepted

**Context:** Wiring the analytics refresh Job to a schedule needs Cloud Scheduler,
which in this project and region requires an App Engine application. An App Engine
app's location is permanent and cannot be changed.

**Decision:** Do not create the App Engine app. The refresh Job runs on demand.
Forcing a permanent, irreversible-region project resource for a portfolio
auto-refresh is not worth it; in a project provisioned with the App Engine region
chosen deliberately, or a region where Cloud Scheduler is decoupled from App
Engine, the schedule wires straight to the existing Job.

**Consequences:** Analytics is refreshed on demand rather than automatically, an
accepted, documented limitation, and the project avoids a permanent constraint
taken under time pressure two metres from the finish line.

## ADR-006: No CI deploy identity for platform-infrastructure

**Status:** Accepted

**Context:** Every service repo has a WIF deploy identity. Symmetry would suggest a
sixth for this repo.

**Decision:** No deploy identity is created for platform-infrastructure unless CI
actually performs authenticated Terraform operations. Infrastructure applies are
deliberately manual and reviewed. A `platform-infra-deploy` identity, treated more
carefully than an ordinary Cloud Run deployer, would be added only if CI apply is
later enabled.

**Consequences:** No credential exists solely to make a screenshot say "six". The
principle (create identities only for what actually authenticates) is upheld even
against the repo's own symmetry.
