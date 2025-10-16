module "customer" {
  source = "../../../modules/customer-stamp"

  create_project = true
  project_id     = var.project_id
  org_id         = var.org_id
  billing_account = var.billing_account
  platform_project_id = var.platform_project_id

  region         = var.region
  artifact_repo_location = var.artifact_repo_location
  artifact_repo_name     = var.artifact_repo_name
  image_name     = var.image_name
  image_tag      = var.image_tag

  cloud_run_service_name = var.cloud_run_service_name
  runtime_sa_name = "run-prod-sa"
  min_instances  = 1

  secrets        = var.secrets
  deployer_sa_email = var.deployer_sa_email

  labels = {
    customer = var.customer_id
    environment = "production"
    managed-by = "terraform"
  }
}
