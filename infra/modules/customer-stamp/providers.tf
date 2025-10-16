terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Default provider targeting the tenant project
provider "google" {
  project = var.project_id
  region  = var.region
}

# Platform provider for cross-project resources (Artifact Registry IAM)
provider "google" {
  alias   = "platform"
  project = var.platform_project_id
  region  = var.region
}
