# Production Log

A running record of what was built and migrated, in what order, and why.
Newest last.

## Milestone 1: Eliminate long-lived deployment keys

**Goal:** Remove the last long-lived CI/CD credentials from the ecosystem. The
ledger and orchestrator still authenticated GitHub Actions with a `GCP_SA_KEY`
JSON key in repository secrets; risk, notification and analytics already deploy
keylessly through Workload Identity Federation. Bring the two stragglers onto the
same model, one at a time, deleting each key only after its keyless deploy is
proven green.

**Repository scaffolded:** `README.md`, `RESOURCE_OWNERSHIP.md` (the one-owner-per-
resource charter), `MIGRATION_RUNBOOK.md` (the repeatable procedure and the
guardrail), and this log.

### ledger-api

- Created the `ledger-deploy` service account with the deploy roles
  (`run.admin`, `artifactregistry.writer`, `iam.serviceAccountUser`) and a
  repository-scoped Workload Identity binding for `abdullahabduljabbarab/ledger-api`.
  (The project-role bindings failed once on the freshly created account and
  succeeded on retry after it propagated.)
- Rewrote the deploy job's auth from `credentials_json: ${{ secrets.GCP_SA_KEY }}`
  to the WIF provider and the `ledger-deploy` account. The job already carried
  `id-token: write`.
- Verified the deploy goes green through WIF and the live ledger is healthy
  (`/health` returned `database: connected`), then deleted the `GCP_SA_KEY`
  secret. The ledger repository now holds no secrets.

### payment-orchestrator

- Created the `orchestrator-deploy` service account with the same deploy roles and
  a repository-scoped Workload Identity binding for
  `abdullahabduljabbarab/payment-orchestrator` (with a propagation wait, so the
  role bindings succeeded first time).
- Rewrote the deploy job's auth from the stored key to WIF and the
  `orchestrator-deploy` account.
- Verified green through WIF and the live orchestrator healthy, then deleted the
  `GCP_SA_KEY` secret.

**Outcome:** every ABS service repository deploys keylessly through Workload
Identity Federation. No long-lived GCP deployment credential remains in any
repository's secrets.

**State:** complete. Both migrated services deployed green through WIF and were
healthy, and both keys were deleted. Verified ecosystem-wide: `GCP_SA_KEY`
appears in zero of the five service repositories. **The ABS platform now holds no
long-lived CI/CD cloud credential.** Next: M2, the Terraform foundation (GCS
remote state, incremental adoption of the WIF pool and shared topics).

## Milestone 2: Terraform foundation

**Goal:** Give the shared infrastructure a single authoritative state rather than
a scatter of declarative copies, adopting the existing live resources
incrementally without recreating anything.

**Built:**
- A versioned GCS bucket, `gs://ledger-api-507618-tfstate`, for Terraform remote
  state.
- `terraform/`: the platform root. `backend.tf` (GCS backend + provider),
  `variables.tf`, `main.tf` (the WIF pool and provider, and the three shared
  topics `transaction-events` / `payment-events` / `risk-events`, written to
  match the live configuration), `imports.tf` (Terraform 1.5+ import blocks
  adopting those five resources), `outputs.tf`, and the provider lock.
- `.github/workflows/terraform.yml`: `fmt`, `init -backend=false`, `validate` on
  Ubuntu.
- `MIGRATION_RUNBOOK.md`: the concrete adoption procedure, run from Cloud Shell.

**Ownership move:** the WIF pool and provider, previously declared in the risk
engine's Terraform and merely referenced by the other services, are now owned
here (RESOURCE_OWNERSHIP.md). Removing the duplicate declaration from the risk
engine's Terraform is an M3 cleanup step.

**Constraint (honest):** this machine's TLS-inspecting network kills Terraform's
provider plugin, the same reason every repo validates Terraform in CI rather than
locally, so `init`/`import`/`plan`/`apply` against live GCP are run from Google
Cloud Shell. The code and the import blocks are written and CI-validated; the
zero-diff reconciliation and apply happen there. The state bucket is created and
versioned.

**Applied from Cloud Shell.** Terraform ran from Cloud Shell (the dev machine
cannot run the provider plugin). `terraform plan` showed the intended adoption:
**5 to import, 0 to add, 1 to change, 0 to destroy**, the WIF pool and the three
topics importing with no changes, and the WIF provider taking one deliberate,
cosmetic change: setting its `display_name` to "GitHub" (it had been created via
gcloud without one; nothing about its issuer, attribute mapping or condition
changed). `terraform apply` completed: **5 imported, 0 added, 1 changed, 0
destroyed**, and `terraform state list` confirms the five resources are now under
Terraform management, with state in
`gs://ledger-api-507618-tfstate/platform/default.tfstate` (versioned). No resource
was recreated.

**State:** complete. Existing shared resources were adopted incrementally into
remote Terraform state without recreation, five imported, none added, none
destroyed, one deliberate provider display-name change. Next: M3, remaining wiring
(analytics Scheduler, IAM cleanup including the orphaned SA keys, de-duplicating
shared definitions from the service repos).

## Milestone 3: Remaining wiring and cleanup

**Orphaned deploy credential fully revoked.** Deleting the `GCP_SA_KEY` GitHub
secrets removed the stored copies, but the underlying GCP key lived on. Found the
owning account, `github-deploy`, which held one user-managed JSON key and no
Workload Identity binding (so the key was its only means of authentication) and
was used only by the now-migrated ledger and orchestrator. Deleted the key, then
the now-inert service account. The credential is dead on both ends.

**Analytics Scheduler: wired.** A first `gcloud scheduler jobs create` failed with
`NOT_FOUND`, which looked like the historical App Engine prerequisite. Retried
after the Cloud Scheduler API had propagated, it succeeded with no App Engine app.
A Cloud Scheduler job now runs the `analytics-refresh` Cloud Run Job every ten
minutes as the dedicated `analytics-scheduler` identity (holding only
`run.invoker` on that Job). Verified live: a manual trigger produced a successful
refresh execution. (ADR-005.)

**Shared-definition de-duplication.** The Workload Identity pool and provider were
declared (created) in the risk engine's Terraform and merely referenced by
notification and analytics. Removed the creation from the risk engine's Terraform
so it references the pool by composed name like the others; platform-infra is now
the sole owner of the pool and provider, matching RESOURCE_OWNERSHIP.md.

**Runtime identity audit** recorded in RESOURCE_OWNERSHIP.md: deploy identity is
fully federated across all five services; the four services still on the default
compute runtime SA are noted as hardening backlog (analytics already uses a
dedicated dataset-scoped runtime SA), with no over-privilege found that warrants
immediate action.

**Docs completed:** ARCHITECTURE, DECISIONS, SECURITY, THREAT_MODEL, bringing the
repo's documentation set to full.

**State:** complete. Next: M4, evidence and freeze.

## Milestone 4: Evidence and freeze

Verified against the live ecosystem:

- **Zero long-lived CI/CD credentials.** `GCP_SA_KEY` appears in zero of the five
  service repositories; the historical `github-deploy` key is revoked and the
  account deleted.
- **Five repository-scoped deploy identities** exist and are the only deploy
  accounts: `ledger-deploy`, `orchestrator-deploy`, `risk-engine-deploy`,
  `notification-service-deploy`, `analytics-service-deploy`, each federated to
  exactly its own repository.
- **All five services healthy** after the migration: ledger, orchestrator, risk,
  notification and analytics each return 200 on `/health`.
- **Shared infrastructure as code** with a versioned GCS remote-state backend and
  incremental import blocks; the platform Terraform validates in CI.
- **Explicit ownership**: one owner per resource (RESOURCE_OWNERSHIP.md), with the
  WIF pool/provider duplication removed from the risk engine's Terraform.

The statement this earns: **five independently deployed services, zero long-lived
CI cloud credentials, repository-scoped OIDC federation, explicit infrastructure
ownership, and shared GCP infrastructure managed as code.**

**Operational follow-ups:** the Terraform import/apply has since been run from
Cloud Shell (remote state populated), and the analytics Scheduler is wired.

**State:** complete. platform-infrastructure is the sixth and final ABS repository;
the ecosystem is assembled.

## Milestone 5: Dedicated runtime identities

**Goal:** Close the last identity gap. Deploy identity was fully federated, but
four of the five services still ran on the shared default compute service account
(only analytics had a dedicated runtime SA). A shared, broad runtime account is
exactly the ambient-authority weakness the deploy migration removed on the CI side.
Give each service its own least-privilege runtime identity.

**Done, one service at a time, safest first**, verifying each live before the next
so a mistake could never cascade through the money path:

1. **notification-service** to `notification-service-runtime`. As a strict sink it
   holds only Cloud SQL Client and read access to its own `notify-database-url`
   secret, with no Pub/Sub role at all.
2. **risk-engine** to `risk-engine-runtime`: Cloud SQL Client, read on
   `risk-database-url`, publisher on `risk-events`.
3. **payment-orchestrator** to `payment-orchestrator-runtime`: Cloud SQL Client,
   read on its own `orchestrator-database-url` and on the `ledger-admin-password`
   it authenticates to the ledger with, publisher on `payment-events`.
4. **ledger-api** to `ledger-api-runtime`, deliberately last as the service that
   owns all financial truth: Cloud SQL Client, read on `database-url` and
   `jwt-secret-key`, publisher on `transaction-events`.

Each service was set via `--service-account` in its deploy, and each service's
Terraform records its runtime account and its exact bindings. The repository-scoped
deploy accounts already held `iam.serviceAccountUser`, so no new act-as binding was
needed.

**Verified live per service:** the runtime account actually switched on the running
revision, `/health` returned `database: connected` (proving both the secret read
and the Cloud SQL connection under the new identity), logs were clean, and a real
business flow ran end to end: a live payment produced a customer notification
delivery (notification), a published `risk.evaluated` (risk), a settled payment
with reserve and capture transactions (orchestrator), and, on the ledger, JWT
signing, deposit/reserve/capture/release transactions with exactly reconciling
balances, and `transaction-events` publishing. Every outbox drain reported
`failed: 0`.

**Outcome:** five services, five dedicated least-privilege runtime identities, none
on the default compute service account. Combined with the deploy migration, the
platform now has no shared ambient authority on either the deploy or the runtime
side.

**State:** complete.
