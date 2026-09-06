# Shared, cross-cutting infrastructure owned by platform-infrastructure. These
# resources already exist live (created by gcloud as the ecosystem was built);
# they are adopted into Terraform state by the import blocks in imports.tf, with
# the configuration below written to match the live resources so the adoption
# plan is zero-diff. No resource is recreated.

# The Workload Identity pool every service repository federates into for keyless
# CI/CD. Previously declared in the risk engine's Terraform; its canonical
# ownership now lives here.
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# The shared event topics. Each is owned by the ecosystem as a whole, not by one
# producer: the ledger publishes to transaction-events, the orchestrator to
# payment-events, the risk engine to risk-events, and several services subscribe.
# (Per-service dead-letter topics stay owned by their consuming service.)
resource "google_pubsub_topic" "transaction_events" {
  name = "transaction-events"
}

resource "google_pubsub_topic" "payment_events" {
  name = "payment-events"
}

resource "google_pubsub_topic" "risk_events" {
  name = "risk-events"
}
