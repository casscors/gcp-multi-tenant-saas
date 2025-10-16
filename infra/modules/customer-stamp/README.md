# Customer Stamp Terraform Module

This module encapsulates all resources for a single tenant or staging environment. It can optionally create the GCP project, enable required APIs, provision Cloud Run, IAM, and Secret Manager metadata, and grant cross-project Artifact Registry access.

## Features

- **Project Management**: Optionally create GCP projects with billing and organization settings
- **Cloud Run Service**: Deploy containerized applications with configurable scaling and resources
- **Secret Management**: Create Secret Manager secrets (metadata only) for secure configuration
- **Cross-Project IAM**: Grant access to centralized Artifact Registry from platform project
- **Service Accounts**: Create and configure runtime service accounts with appropriate permissions

## Usage

### Staging Environment
```hcl
module "staging" {
  source = "../../modules/customer-stamp"
  
  create_project = false
  project_id     = var.staging_project_id
  platform_project_id = var.platform_project_id
  
  region         = var.region
  artifact_repo_location = var.artifact_repo_location
  artifact_repo_name     = var.artifact_repo_name
  image_name     = var.image_name
  image_tag      = var.image_tag
  
  cloud_run_service_name = "app-staging"
  runtime_sa_name = "run-staging-sa"
  min_instances  = 1
  
  secrets = var.secrets
  deployer_sa_email = var.deployer_sa_email
}
```

### Customer Environment
```hcl
module "customer" {
  source = "../../modules/customer-stamp"
  
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
  
  cloud_run_service_name = "app"
  runtime_sa_name = "run-prod-sa"
  min_instances  = 1
  
  secrets = var.secrets
  deployer_sa_email = var.deployer_sa_email
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_project | Whether to create a new GCP project | `bool` | `false` | no |
| project_id | Target project ID to use or create | `string` | n/a | yes |
| platform_project_id | Platform project ID where Artifact Registry lives | `string` | n/a | yes |
| image_tag | Container image tag to deploy | `string` | n/a | yes |
| secrets | Map of secrets to create and map to environment variables | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | The project ID |
| cloud_run_url | The Cloud Run service URL |
| runtime_service_account_email | The runtime service account email |

## Design Notes

- Creating projects requires elevated org-level permissions
- Cross-project IAM is handled via alias provider targeting the platform project
- Secret versions are not created in Terraform to avoid storing plaintext in state
- Image updates via Terraform create new Cloud Run revisions without drift
