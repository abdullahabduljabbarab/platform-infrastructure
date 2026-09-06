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

**State:** Terraform written and CI-validated, remote-state bucket live. The
incremental import/apply (to zero-diff plans) is the operational step run in a
Terraform-capable environment. Next: M3, remaining wiring (analytics Scheduler,
IAM cleanup including the orphaned SA keys, de-duplicating shared definitions from
the service repos).
