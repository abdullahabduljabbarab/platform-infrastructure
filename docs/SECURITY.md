# Security

## What this repository is

A portfolio demonstration of the ecosystem's shared infrastructure and its
deployment/security posture. It holds no application code and no data. Its subject
is the platform's identity model: how services deploy, and who owns what.

## The property this establishes

**Zero long-lived CI/CD cloud credentials.** Every service repository deploys
through repository-scoped Workload Identity Federation, a short-lived GitHub OIDC
token exchanged for impersonation of a per-repo deploy service account. No
service-account JSON key is stored in any repository. This was completed by
migrating the last two services (ledger, orchestrator) off `GCP_SA_KEY`, deleting
the secrets, and revoking the underlying GCP key of the shared `github-deploy`
account (then deleting the now-inert account). The credential is dead on both
ends: no stored secret, and no key in GCP.

Verified ecosystem-wide: `GCP_SA_KEY` appears in zero of the five service
repositories.

## Boundaries

**Repository-scoped federation.** The Workload Identity provider's
`attribute_condition` restricts token exchange to the owner's repositories, and
each deploy service account's `workloadIdentityUser` binding names exactly one
repository. A different repository, even under the same owner, cannot impersonate
another service's deploy account.

**Least-privilege deploy accounts.** Each `<service>-deploy` account holds only the
roles its pipeline needs (`run.admin`, `artifactregistry.writer`,
`iam.serviceAccountUser`).

**No key material in Terraform or Git.** Deployment is keyless, so no key is
generated to leak; `.gitignore` excludes Terraform state and any stray key files.

**Remote state, not local.** Terraform state lives in a versioned GCS bucket, not
in the repository, so infrastructure state is never committed.

**Manual, reviewed applies.** Infrastructure applies are deliberately not run in
CI, so no CI credential can mutate shared infrastructure. If CI apply is later
enabled, it gets its own carefully-scoped identity (ADR-006).

## Known limitations and backlog

- **Runtime identities.** Both deploy and runtime identity are now hardened. Every
  service runs under a dedicated, least-privilege runtime account, none on the
  default compute service account. The migration was done one service at a time,
  safest first (notification, risk, orchestrator, ledger), verifying each live
  before the next. Each account holds only Cloud SQL Client, read access to its
  own secrets, and publisher on its own topic where it produces events;
  notification, a strict sink, has no Pub/Sub role at all.
- **Incremental Terraform adoption.** Only the WIF pool/provider and shared topics
  are adopted; project-level IAM and the Cloud SQL instance are documented but not
  yet under Terraform lifecycle, deliberately, to avoid drift.
