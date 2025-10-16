output "project_id" {
  description = "The project ID"
  value       = var.project_id
}

output "cloud_run_url" {
  description = "The Cloud Run service URL"
  value       = google_cloud_run_v2_service.service.uri
}

output "runtime_service_account_email" {
  description = "The runtime service account email"
  value       = google_service_account.runtime_sa.email
}

output "service_name" {
  description = "The Cloud Run service name"
  value       = google_cloud_run_v2_service.service.name
}

output "service_location" {
  description = "The Cloud Run service location"
  value       = google_cloud_run_v2_service.service.location
}
