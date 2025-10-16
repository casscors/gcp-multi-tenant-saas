terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.staging_project_id
  region  = var.region
}

provider "google" {
  alias   = "platform"
  project = var.platform_project_id
  region  = var.region
}
