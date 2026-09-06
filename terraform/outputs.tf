output "workload_identity_pool" {
  description = "The shared GitHub Actions Workload Identity pool"
  value       = google_iam_workload_identity_pool.github.name
}

output "workload_identity_provider" {
  description = "The GitHub OIDC provider service repositories present tokens to"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "shared_topics" {
  description = "The shared event topics owned by the platform"
  value = [
    google_pubsub_topic.transaction_events.id,
    google_pubsub_topic.payment_events.id,
    google_pubsub_topic.risk_events.id,
  ]
}
