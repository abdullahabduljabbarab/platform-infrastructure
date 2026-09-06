variable "project_id" {
  description = "GCP project ID for the ABS platform"
  type        = string
  default     = "ledger-api-507618"
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "europe-west2"
}

variable "github_owner" {
  description = "GitHub owner whose repositories may federate into the pool"
  type        = string
  default     = "abdullahabduljabbarab"
}
