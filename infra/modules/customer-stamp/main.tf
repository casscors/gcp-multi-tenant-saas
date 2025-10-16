# Computed values
locals {
  image_url = "${var.artifact_repo_location}-docker.pkg.dev/${var.platform_project_id}/${var.artifact_repo_name}/${var.image_name}:${var.image_tag}"
}

# Conditionally create project
resource "google_project" "project" {
  count = var.create_project ? 1 : 0

  name            = var.project_id
  project_id      = var.project_id
  org_id          = var.org_id
  billing_account = var.billing_account
  labels          = var.labels
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = var.create_project ? toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ]) : toset([])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy        = false

  depends_on = [google_project.project]
}

# Runtime service account
resource "google_service_account" "runtime_sa" {
  account_id   = var.runtime_sa_name
  display_name = "Cloud Run Runtime Service Account"
  project      = var.project_id
}

# Grant deployer permissions (if deployer SA provided)
resource "google_project_iam_member" "deployer_run_admin" {
  count = var.deployer_sa_email != "" ? 1 : 0

  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${var.deployer_sa_email}"
}

resource "google_service_account_iam_member" "deployer_sa_user" {
  count = var.deployer_sa_email != "" ? 1 : 0

  service_account_id = google_service_account.runtime_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.deployer_sa_email}"
}

resource "google_project_iam_member" "deployer_secret_admin" {
  count = var.deployer_sa_email != "" ? 1 : 0

  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${var.deployer_sa_email}"
}

resource "google_project_iam_member" "deployer_service_usage" {
  count = var.deployer_sa_email != "" ? 1 : 0

  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${var.deployer_sa_email}"
}

# Create Secret Manager secrets (metadata only)
resource "google_secret_manager_secret" "secrets" {
  for_each = var.manage_secret_resources ? var.secrets : {}

  secret_id = each.value.secret_id
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# Cloud Run service
resource "google_cloud_run_v2_service" "service" {
  name     = var.cloud_run_service_name
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.runtime_sa.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = local.image_url

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = "3000"
      }

      # Environment variables from secrets
      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.value.env_var
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.secrets[env.key].secret_id
              version = "latest"
            }
          }
        }
      }
    }

    ingress_settings = var.ingress
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [google_project_service.apis]
}

# Cross-project Artifact Registry IAM
resource "google_artifact_registry_repository_iam_member" "runtime_ar_reader" {
  provider = google.platform

  location   = var.artifact_repo_location
  repository  = var.artifact_repo_name
  role        = "roles/artifactregistry.reader"
  member      = "serviceAccount:${google_service_account.runtime_sa.email}"
}
