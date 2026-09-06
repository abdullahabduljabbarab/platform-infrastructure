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
