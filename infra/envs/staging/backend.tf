terraform {
  backend "gcs" {
    bucket = "gcp-terraform-state-bucket"
    prefix = "envs/staging"
  }
}
