terraform {
  required_version = ">= 1.5"

  # Remote state in a versioned GCS bucket, so the shared platform infrastructure
  # has a single authoritative state rather than living only as a declarative
  # record. CI validates with -backend=false; real init/plan/apply run where
  # Terraform's provider plugin can execute (Cloud Shell), against this backend.
  backend "gcs" {
    bucket = "ledger-api-507618-tfstate"
    prefix = "platform"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
