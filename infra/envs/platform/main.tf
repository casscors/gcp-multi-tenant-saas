# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com"
  ])

  project = var.platform_project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy        = false
}

# Artifact Registry repository
resource "google_artifact_registry_repository" "apps" {
  location      = var.region
  repository_id = var.artifact_repo_name
  description   = "Centralized container registry for all applications"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

# GCS bucket for Terraform remote state
resource "google_storage_bucket" "terraform_state" {
  name          = var.state_bucket_name
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.apis]
}

# Workload Identity Federation Pool
resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"
  project                   = var.platform_project_id

  depends_on = [google_project_service.apis]
}

# Workload Identity Federation Provider
resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions Provider"
  description                        = "OIDC identity pool provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  project = var.platform_project_id
}

# CI Terraform Service Account
resource "google_service_account" "ci_terraform" {
  account_id   = "ci-terraform"
  display_name = "CI Terraform Service Account"
  description  = "Service account for CI/CD Terraform operations"
  project      = var.platform_project_id
}

# Grant CI service account permissions
resource "google_project_iam_member" "ci_project_creator" {
  project = var.platform_project_id
  role    = "roles/resourcemanager.projectCreator"
  member  = "serviceAccount:${google_service_account.ci_terraform.email}"
}

resource "google_project_iam_member" "ci_billing_user" {
  project = var.platform_project_id
  role    = "roles/billing.user"
  member  = "serviceAccount:${google_service_account.ci_terraform.email}"
}

resource "google_project_iam_member" "ci_service_account_admin" {
  project = var.platform_project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.ci_terraform.email}"
}

resource "google_project_iam_member" "ci_run_admin" {
  project = var.platform_project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.ci_terraform.email}"
}

resource "google_project_iam_member" "ci_artifact_registry_admin" {
  project = var.platform_project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.ci_terraform.email}"
}

resource "google_project_iam_member" "ci_secret_manager_admin" {
  project = var.platform_project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${google_service_account.ci_terraform.email}"
}

resource "google_project_iam_member" "ci_service_usage_admin" {
  project = var.platform_project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.ci_terraform.email}"
}

# Bind GitHub Actions to CI service account
resource "google_service_account_iam_binding" "github_actions_binding" {
  service_account_id = google_service_account.ci_terraform.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_org}/${var.github_repo}"
  ]
}
