# Declarative adoption of the existing live resources (Terraform 1.5+ import
# blocks). Running `terraform plan` reconciles each against its live state; the
# adoption proceeds only when the plan is zero-diff or every difference is
# understood and intended. Nothing is recreated. Adopt incrementally: comment out
# all but the resource being adopted if a plan needs to be read one at a time.

import {
  to = google_iam_workload_identity_pool.github
  id = "projects/ledger-api-507618/locations/global/workloadIdentityPools/github-actions"
}

import {
  to = google_iam_workload_identity_pool_provider.github
  id = "projects/ledger-api-507618/locations/global/workloadIdentityPools/github-actions/providers/github"
}

import {
  to = google_pubsub_topic.transaction_events
  id = "projects/ledger-api-507618/topics/transaction-events"
}

import {
  to = google_pubsub_topic.payment_events
  id = "projects/ledger-api-507618/topics/payment-events"
}

import {
  to = google_pubsub_topic.risk_events
  id = "projects/ledger-api-507618/topics/risk-events"
}
