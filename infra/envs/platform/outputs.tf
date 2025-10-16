output "platform_project_id" {
  description = "The platform project ID"
  value       = var.platform_project_id
}

output "artifact_registry_repository" {
  description = "The Artifact Registry repository name"
  value       = google_artifact_registry_repository.apps.name
}

output "artifact_registry_location" {
  description = "The Artifact Registry repository location"
  value       = google_artifact_registry_repository.apps.location
}

output "terraform_state_bucket" {
  description = "The GCS bucket for Terraform state"
  value       = google_storage_bucket.terraform_state.name
}

output "ci_service_account_email" {
  description = "The CI Terraform service account email"
  value       = google_service_account.ci_terraform.email
}

output "workload_identity_pool_id" {
  description = "The Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.github_actions.name
}

output "workload_identity_provider_id" {
  description = "The Workload Identity Provider ID"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}
