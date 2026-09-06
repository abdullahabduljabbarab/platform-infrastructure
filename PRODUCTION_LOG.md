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
- Verified the deploy goes green through WIF and the live ledger is healthy, then
  deleted the `GCP_SA_KEY` secret.

**State:** in progress.
