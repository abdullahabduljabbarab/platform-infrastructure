# Engineering portal (abs-portal)
#
# The portal is a single Cloud Run service that serves the BFF and the built
# frontend. Its deploy infrastructure lives here, in platform-infrastructure,
# rather than in the umbrella repository: the portal is the system-level surface
# over the whole ecosystem, and the platform owns how it deploys. This is the
# declarative record; the resources are provisioned by the umbrella repository's
# keyless CI, and adoption into remote state is a follow-up via import blocks, the
# same incremental approach used for the shared pool and topics.

resource "google_artifact_registry_repository" "abs_portal" {
  location      = var.region
  repository_id = "abs-portal"
  format        = "DOCKER"
}

# Repository-scoped keyless deploy identity, matching every service's deploy model.
resource "google_service_account" "abs_portal_deploy" {
  account_id   = "abs-portal-deploy"
  display_name = "ABS Portal Deploy"
}

resource "google_project_iam_member" "abs_portal_deploy_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.abs_portal_deploy.email}"
}

# Only the abs-financial-systems repository may impersonate the deploy account.
resource "google_service_account_iam_member" "abs_portal_deploy_wif" {
  service_account_id = google_service_account.abs_portal_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/abs-financial-systems"
}

# The portal runs as a dedicated identity with no cloud permissions: it holds no
# secrets, touches no database, and only makes outbound HTTPS calls to the
# services' public read APIs.
resource "google_service_account" "abs_portal_runtime" {
  account_id   = "abs-portal-runtime"
  display_name = "ABS Portal Runtime"
}

resource "google_cloud_run_v2_service" "abs_portal" {
  name     = "abs-portal"
  location = var.region

  template {
    service_account = google_service_account.abs_portal_runtime.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/abs-portal/abs-portal:latest"
      ports {
        container_port = 8080
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
  }
}

# The portal is the public face of the ecosystem.
resource "google_cloud_run_v2_service_iam_member" "abs_portal_public" {
  name     = google_cloud_run_v2_service.abs_portal.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
