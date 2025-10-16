# Project management
variable "create_project" {
  description = "Whether to create a new GCP project"
  type        = bool
  default     = false
}

variable "project_id" {
  description = "Target project ID to use or create"
  type        = string
}

variable "org_id" {
  description = "Organization ID (required when create_project = true)"
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing account ID (required when create_project = true)"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels to apply to the project"
  type        = map(string)
  default     = {}
}

# Location and naming
variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "app"
}

# Image and registry
variable "platform_project_id" {
  description = "Platform project ID where Artifact Registry lives"
  type        = string
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

# Runtime and scaling
variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "cpu" {
  description = "CPU allocation for Cloud Run service"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation for Cloud Run service"
  type        = string
  default     = "512Mi"
}

variable "concurrency" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 80
}

variable "ingress" {
  description = "Ingress configuration for Cloud Run"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

# Service accounts and deployers
variable "runtime_sa_name" {
  description = "Runtime service account name"
  type        = string
  default     = "run-sa"
}

variable "deployer_sa_email" {
  description = "Service account email allowed to deploy/update the service"
  type        = string
  default     = ""
}

# Secrets
variable "manage_secret_resources" {
  description = "Whether to manage Secret Manager secret resources"
  type        = bool
  default     = true
}

variable "secrets" {
  description = "Map of secrets to create and map to environment variables"
  type = map(object({
    secret_id = string
    env_var   = string
  }))
  default = {}
}
