output "staging_project_id" {
  description = "The staging project ID"
  value       = module.staging.project_id
}

output "cloud_run_url" {
  description = "The staging Cloud Run service URL"
  value       = module.staging.cloud_run_url
}

output "runtime_service_account_email" {
  description = "The staging runtime service account email"
  value       = module.staging.runtime_service_account_email
}
