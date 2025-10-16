variable "customer_id" {
  description = "Customer identifier"
  type        = string
  default     = "globex"
}

variable "project_id" {
  description = "Customer project ID"
  type        = string
  default     = "proj-globex-prod"
}

variable "org_id" {
  description = "Organization ID"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
}

variable "platform_project_id" {
  description = "Platform project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "artifact_repo_location" {
  description = "Artifact Registry repository location"
  type        = string
  default     = "us-central1"
}

variable "artifact_repo_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "apps"
}

variable "image_name" {
  description = "Container image name"
  type        = string
  default     = "gcp-app"
}

variable "image_tag" {
  description = "Container image tag to deploy"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "app"
}

variable "secrets" {
  description = "Map of secrets to create and map to environment variables"
  type = map(object({
    secret_id = string
    env_var   = string
  }))
  default = {}
}

variable "deployer_sa_email" {
  description = "Service account email allowed to deploy/update the service"
  type        = string
  default     = ""
}
