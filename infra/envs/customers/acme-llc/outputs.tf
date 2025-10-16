output "customer_project_id" {
  description = "The customer project ID"
  value       = module.customer.project_id
}

output "cloud_run_url" {
  description = "The customer Cloud Run service URL"
  value       = module.customer.cloud_run_url
}

output "runtime_service_account_email" {
  description = "The customer runtime service account email"
  value       = module.customer.runtime_service_account_email
}

output "service_name" {
  description = "The Cloud Run service name"
  value       = module.customer.service_name
}

output "service_location" {
  description = "The Cloud Run service location"
  value       = module.customer.service_location
}
