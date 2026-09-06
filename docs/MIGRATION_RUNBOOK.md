# Migration Runbook

The procedures this repository executed, written so they are repeatable and so the
guardrail is explicit: **migrate one service or resource at a time, and verify
live behaviour before continuing.** The platform stays fully live throughout.

## Keyless-deploy migration (per service)

Applied to `ledger-api` and `payment-orchestrator`, the two services that still
authenticated CI with a long-lived `GCP_SA_KEY`. The order matters: the keyless
path is proven green before the key is removed, so there is never a window where
neither works.

1. **Create the deploy service account** and grant it the deploy roles the
   pipeline needs (`run.admin`, `artifactregistry.writer`,
   `iam.serviceAccountUser`).

   ```
   gcloud iam service-accounts create <svc>-deploy --display-name "<Svc> Deploy"
   gcloud projects add-iam-policy-binding <project> \
     --member serviceAccount:<svc>-deploy@<project>.iam.gserviceaccount.com \
     --role roles/run.admin        # and artifactregistry.writer, iam.serviceAccountUser
   ```

2. **Bind the repository to the deploy account** through the shared Workload
   Identity pool, so only that repository can impersonate it.

   ```
   gcloud iam service-accounts add-iam-policy-binding \
     <svc>-deploy@<project>.iam.gserviceaccount.com \
     --role roles/iam.workloadIdentityUser \
     --member "principalSet://iam.googleapis.com/projects/<number>/locations/global/workloadIdentityPools/github-actions/attribute.repository/<owner>/<repo>"
   ```

   (A newly created service account can take a few seconds to propagate before it
   is accepted as an IAM member; retry the role binding if it fails once.)

3. **Rewrite the deploy job's auth** from the stored key to WIF. The job already
   needs `permissions: id-token: write`.

   ```yaml
   # before
   - uses: google-github-actions/auth@v2
     with:
       credentials_json: ${{ secrets.GCP_SA_KEY }}
   # after
   - uses: google-github-actions/auth@v2
     with:
       project_id: <project>
       workload_identity_provider: projects/<number>/locations/global/workloadIdentityPools/github-actions/providers/github
       service_account: <svc>-deploy@<project>.iam.gserviceaccount.com
   ```

4. **Push and verify the deploy goes green** through WIF, and confirm the live
   service is still healthy.

5. **Only then, delete the long-lived secret.**

   ```
   gh secret delete GCP_SA_KEY --repo <owner>/<repo>
   ```

If step 4 fails, the old key is still present and the previous revision is still
serving; fix the WIF setup and retry before touching the secret.

## Terraform adoption (hybrid, incremental)

Shared infrastructure is brought under Terraform with a GCS remote-state backend
(`gs://ledger-api-507618-tfstate`, prefix `platform`, versioned), but adopted
incrementally rather than mass-imported, so a heavily-defaulted live resource
cannot be accidentally mutated.

The adoption is declared with Terraform 1.5+ **import blocks** in
[`terraform/imports.tf`](../terraform/imports.tf): the WIF pool and provider and the
three shared Pub/Sub topics. Their `resource` blocks in `main.tf` are written to
match the live configuration so the plan is zero-diff.

**Where to run it.** This machine's TLS-inspecting network kills Terraform's
provider plugin (the same reason every repo validates in CI, not locally), so
`init`/`plan`/`apply` run from **Google Cloud Shell**, where Terraform is
preinstalled, credentials are present, and there is no interception:

```
# in Cloud Shell, from the terraform/ directory of this repo
terraform init                       # connects to the GCS backend
terraform plan                       # reconciles the import blocks against live state
# read the plan: it should show the resources being IMPORTED with NO changes.
# if a resource shows a diff, adjust its block in main.tf to match live, re-plan,
# and only proceed when the diff is zero or every difference is intended.
terraform apply                      # writes the imported resources into remote state
```

Adopt incrementally: to read one resource's plan at a time, comment out the other
import blocks first. No `apply` runs against an imported resource until its plan
is zero-diff or the differences are deliberate.

The Cloud SQL instance (`ledger-db`) is deliberately **not** adopted; it stays
owned by ledger-api and is referenced as a data source, to avoid drift on a
heavily-defaulted resource. Project-level IAM and API enablement are likewise
left documented for a later, careful pass rather than mass-imported now.
