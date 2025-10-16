# GCP Multi-Tenant Infrastructure

> **Quick Start:** If you're ready to deploy, see `docs/QUICK_START.md` first!
> 
> **Secrets Setup:** For GitHub and GCP secrets configuration, see `docs/SECRETS_SETUP.md`
> 
> **Reference:** For a complete secrets reference, see `docs/SECRETS_REFERENCE.md`

## High-level architecture overview
- Control plane (platform project)
  - Google Artifact Registry: single, centralized repository hosting all versioned images for staging and production.
  - Terraform state bucket (GCS) and optional KMS key for state encryption.
  - Workload Identity Federation (WIF) for GitHub Actions to access GCP without saving keys.
  - Optional org-level resources like budget alerts, org policies, or logging sinks.
- Staging plane (shared staging project)
  - Cloud Run service for staging with min-instances = 1.
  - Project-local secrets in Secret Manager for staging configs.
  - Cloud Run runtime service account granted Artifact Registry reader on the platform repo.
- Production plane (one project per customer)
  - One dedicated GCP project per customer.
  - Cloud Run service per customer with min-instances = 1.
  - Project-local secrets in Secret Manager for customer configs.
  - Cloud Run runtime service account granted Artifact Registry reader on the platform repo.
- CI/CD
  - GitHub Actions with OIDC -> WIF in platform project. Actions deploy to staging on branch push, and to a specific customer on semantic tag push matching convention.
- Local development
  - Minikube or Docker Desktop Kubernetes.
  - K8s manifests (base + local overlay) or Helm chart.
  - Local workflow builds the same image name/tag you deploy to Cloud Run; can use local registry or Minikube Docker daemon.


## Recommended repository and Terraform structure
Root at: ~/Developer/GCP/`<your-repo-name>`
- app/
  - Dockerfile
  - src/... (your app)
- k8s/
  - base/
    - deployment.yaml (Deployment referencing image and env via config/secret)
    - service.yaml
    - configmap.yaml
    - secret.yaml (templated, never commit real values)
  - overlays/
    - local/
      - kustomization.yaml (patch image to local tag, mount dev config)
- infra/
  - modules/
    - customer-stamp/
      - main.tf
      - variables.tf
      - outputs.tf
      - providers.tf
      - README.md
  - envs/
    - platform/
      - main.tf (Artifact Registry, WIF, state bucket, optional KMS, IAM)
      - variables.tf
      - providers.tf
      - backend.tf
    - staging/
      - main.tf (calls customer-stamp with create_project=false)
      - variables.tf
      - providers.tf
      - backend.tf
      - terraform.tfvars.example
    - customers/
      - `<customer-id>`/  # e.g., acme-llc, globex
        - main.tf (calls customer-stamp, typically create_project=true)
        - variables.tf
        - providers.tf
        - backend.tf
        - terraform.tfvars.example (git-ignored real .tfvars)
  - shared.tfvars.example (common defaults; never store secrets)
- .github/
  - workflows/
    - staging.yml
    - prod-tag.yml
- scripts/
  - parse-tag.sh (extracts customer-id and version from git tag)
  - tf-wrapper.sh (sets backend and providers dynamically; optional)
- .gitignore (ignore *.tfvars, local kube secrets, etc.)
- README.md


## Customer-stamp Terraform module design
Scope: A reusable module that encapsulates all resources for a single tenant or staging environment. It can optionally create the GCP project, enable required APIs, provision Cloud Run, IAM, and Secret Manager metadata, and grant cross-project Artifact Registry access.

### Files and key contents
- modules/customer-stamp/providers.tf
  - Define:
    - provider "google" (default): points to the target tenant project.
    - provider "google" alias = "platform": points to the platform project (for cross-project Artifact Registry IAM).
  - Example:
    - provider "google" { project = var.project_id, region = var.region }
    - provider "google" { alias = "platform", project = var.platform_project_id, region = var.region }

- modules/customer-stamp/variables.tf (module “signature”)
  - project management
    - variable "create_project" (bool): whether to create a new project.
    - variable "project_id" (string): target project id to use/create.
    - variable "org_id" (string): required when create_project = true.
    - variable "billing_account" (string): required when create_project = true.
    - variable "labels" (map(string)) optional.
  - location and naming
    - variable "region" (string)
    - variable "cloud_run_service_name" (string)
  - image and registry
    - variable "platform_project_id" (string): where Artifact Registry lives.
    - variable "artifact_repo_location" (string): e.g., "us-central1".
    - variable "artifact_repo_name" (string): e.g., "apps".
    - variable "image_name" (string): e.g., "myapp".
    - variable "image_tag" (string): image tag to deploy.
  - runtime and scaling
    - variable "min_instances" (number) default 1
    - variable "max_instances" (number) default 10
    - variable "cpu" (string) default "1"
    - variable "memory" (string) default "512Mi"
    - variable "concurrency" (number) default 80
    - variable "ingress" (string) default "INGRESS_TRAFFIC_ALL"
  - service accounts and deployers
    - variable "runtime_sa_name" (string) default "run-sa"
    - variable "deployer_sa_email" (string): SA allowed to deploy/update the service via Terraform (for CI).
  - secrets
    - variable "manage_secret_resources" (bool) default true
    - variable "secrets" (map(object({
        secret_id = string  // the Secret Manager secret id (name)
        env_var  = string   // env var to map in Cloud Run
      })))
    - Note: The module creates secret metadata, not versions. Values are added by CI or local ops.
  - outputs include:
    - output "project_id"
    - output "cloud_run_url"
    - output "runtime_service_account_email"

- modules/customer-stamp/main.tf (logic and resources)
  - Conditionally create project (when create_project = true)
    - google_project
    - google_project_service for required APIs:
      - run.googleapis.com
      - artifactregistry.googleapis.com
      - secretmanager.googleapis.com
      - iam.googleapis.com
      - cloudresourcemanager.googleapis.com
      - serviceusage.googleapis.com
      - monitoring.googleapis.com
      - logging.googleapis.com
  - Create runtime service account (google_service_account)
  - Grant deployer permissions in the tenant project (if deployer_sa_email provided)
    - roles/run.admin on project to deploy Cloud Run
    - roles/iam.serviceAccountUser on runtime SA
    - roles/secretmanager.admin or roles/secretmanager.secretAccessor if CI will only read/add versions
    - roles/serviceusage.serviceUsageConsumer (to use enabled APIs)
  - Create Secret Manager “secret” resources (metadata only) if manage_secret_resources = true
    - google_secret_manager_secret for each entry in var.secrets
    - do NOT create secret versions to avoid storing cleartext in Terraform state
  - Cloud Run service: google_cloud_run_v2_service
    - service template:
      - service_account: runtime SA
      - containers:
        - image: "REGION-docker.pkg.dev/PLATFORM_PROJECT/REPO/IMAGE_NAME:IMAGE_TAG"
        - env:
          - for each secret in var.secrets, use env.valueSource.secretKeyRef with version "latest"
      - scaling settings min_instance_count = var.min_instances, max_instance_count = var.max_instances
      - ingress config var.ingress
      - container resources cpu/memory var settings
      - concurrency var.concurrency
  - Cross-project Artifact Registry IAM granting runtime SA pull access
    - google_artifact_registry_repository_iam_member (provider = google.platform)
      - repository: var.artifact_repo_name in var.artifact_repo_location
      - member: serviceAccount:runtime_sa_email
      - role: roles/artifactregistry.reader

- modules/customer-stamp/outputs.tf
  - output "cloud_run_url" from google_cloud_run_v2_service.uri
  - output "runtime_service_account_email" from SA
    - output "project_id"

### Key design notes and side effects
- Creating projects requires elevated org-level permissions (resourcemanager.projectCreator and billing.projectManager or billing.user) in the platform CI SA.
- Using central Artifact Registry introduces cross-project IAM; the module handles this via an alias provider targeting the platform project.
- Avoid creating secret versions in Terraform to keep payloads out of state; use CI or manual gcloud to add versions.
- Updating only the image tag via Terraform will create a new Cloud Run revision without drift in other settings.


## Platform environment (infra/envs/platform)
Purpose: Bootstrap shared resources once.

### Files and responsibilities
- providers.tf
  - provider "google" project = var.platform_project_id
- backend.tf
  - Configure GCS backend for Terraform state
- variables.tf
  - platform_project_id, org_id, billing_account, region(s), repo metadata (org/repo for GitHub Actions)
- main.tf
  - Artifact Registry
    - google_artifact_registry_repository "apps" (format: DOCKER)
    - Regions per your latency/cost preference (start with one region)
  - GCS bucket for Terraform remote state
    - google_storage_bucket with uniform bucket-level access
    - Optional: CMEK via KMS
  - Workload Identity Federation for GitHub Actions
    - google_iam_workload_identity_pool
    - google_iam_workload_identity_pool_provider (issuer: https://token.actions.githubusercontent.com)
    - Service account for CI:
      - google_service_account "ci-terraform"
      - Grant:
        - roles/iam.workloadIdentityUser (bind GitHub OIDC subject to this SA)
        - roles/resourcemanager.projectCreator (create customer projects)
        - roles/billing.user (link billing)
        - roles/iam.serviceAccountAdmin (create/manage project SAs as needed)
        - roles/run.admin (deploy/update Cloud Run)
        - roles/artifactregistry.admin (manage repo and IAM)
        - roles/secretmanager.admin (create secrets metadata; optional)
        - roles/serviceusage.serviceUsageAdmin (enable services)
    - IAM binding for WIF:
      - google_service_account_iam_binding on ci-terraform SA with principalSet from WIF provider (GitHub repo subject)
  - Optional: budget alerts, KMS keyring/keys

Critical decision: You may separate staging from platform; for simplicity keep central AR and WIF in platform project. Staging can be a separate project to avoid CI privileges overlapping with staging resources.


## Staging environment (infra/envs/staging)

### Files and logic
- providers.tf
  - provider "google" project = var.staging_project_id
  - provider "google" alias = "platform" project = var.platform_project_id
- backend.tf for remote state
- variables.tf
  - staging_project_id, platform_project_id, region, artifact_repo_name/location, image_name
  - cloud_run_service_name default "app-staging"
  - secrets map (by names only)
- main.tf
  - module "staging" { source = "../../modules/customer-stamp"
      create_project = false
      project_id     = var.staging_project_id
      platform_project_id = var.platform_project_id
      region         = var.region
      artifact_repo_location = var.artifact_repo_location
      artifact_repo_name     = var.artifact_repo_name
      image_name     = var.image_name
      image_tag      = var.image_tag   // set from CI pipeline
      cloud_run_service_name = var.cloud_run_service_name
      runtime_sa_name = "run-staging-sa"
      min_instances  = 1
      secrets        = var.secrets
      deployer_sa_email = var.deployer_sa_email
    }

### Side effects
- Using the module for staging provides uniform config and ensures minimum instances set to avoid cold starts.
- Secrets must exist in the staging project Secret Manager with versions; CI can create/update versions from GitHub Secrets.


## Customer environments (infra/envs/customers/`<id>`)

### Files and logic
- providers.tf
  - provider "google" default will point to var.project_id after project exists; for first run, can point to platform SA with resourcemanager permissions; Terraform can still create project using google provider with credentials at org scope
  - provider "google" alias = "platform" project = var.platform_project_id
- backend.tf for remote state; use key prefix customers/`<id>`
- variables.tf
  - customer_id
  - project_id (derived naming like cust-`<id>`-prod)
  - org_id, billing_account (for project creation)
  - platform_project_id, region, artifact_repo_name/location, image_name
  - cloud_run_service_name default "app"
  - secrets map (names only)
- main.tf
  - module "customer" { source = "../../../modules/customer-stamp"
      create_project = true
      project_id     = var.project_id
      org_id         = var.org_id
      billing_account = var.billing_account
      platform_project_id = var.platform_project_id
      region         = var.region
      artifact_repo_location = var.artifact_repo_location
      artifact_repo_name     = var.artifact_repo_name
      image_name     = var.image_name
      image_tag      = var.image_tag  // set by prod tag pipeline
      cloud_run_service_name = var.cloud_run_service_name
      runtime_sa_name = "run-prod-sa"
      min_instances  = 1
      secrets        = var.secrets
      deployer_sa_email = var.deployer_sa_email
    }

### Side effects
- The first apply will create the project and all infra but will fail to resolve image and secret versions if they are missing. In practice:
  - Run apply once to create infra + secret metadata.
  - Add secrets versions via CI or manually.
  - Push a production tag with a version that exists in Artifact Registry to deploy the service revision.


## Key Terraform data structures (module variable examples)
- variable "secrets" example:
  - type = map(object({ secret_id = string, env_var = string }))
  - Value example:
    - {
        "APP_CONFIG" = { secret_id = "app-config", env_var = "APP_CONFIG" },
        "DB_URL"     = { secret_id = "db-url",     env_var = "DATABASE_URL" }
      }
- Computed image URL inside module:
  - local.image = "${var.artifact_repo_location}-docker.pkg.dev/${var.platform_project_id}/${var.artifact_repo_name}/${var.image_name}:${var.image_tag}"


## CI/CD workflows (step-by-step English descriptions)

### Common elements for both pipelines
- Authenticate to GCP using GitHub Actions OIDC -> WIF provider in platform project.
- Impersonate the ci-terraform service account.
- Configure Docker to push to Artifact Registry: gcloud auth configure-docker ${region}-docker.pkg.dev
- Use Terraform with GCS backend; provide -backend-config or rely on backend.tf committed in envs.

### Staging pipeline (trigger: push to staging branch)
1) Checkout repository. Derive image tag (e.g., staging-`<shortsha>`).
2) OIDC authenticate to GCP WIF and impersonate ci-terraform@platform.
3) Build container:
   - docker build -t ${REGION}-docker.pkg.dev/${PLATFORM_PROJECT}/${REPO}/${IMAGE_NAME}:${TAG} .
4) Push image to Artifact Registry.
5) Ensure staging secrets exist in Secret Manager (only metadata defined in Terraform; versions managed outside TF). Optionally add versions from GitHub Actions Secrets:
   - gcloud secrets versions add app-config --data-file=\<(printenv APP_CONFIG)
6) Terraform apply envs/platform (first time only) is done beforehand; here:
   - cd infra/envs/staging
   - terraform init (GCS backend)
   - terraform apply -auto-approve -var image_tag=${TAG}
   - This updates the Cloud Run service to the new image tag; min-instances = 1 ensures no cold starts.
7) Output the Cloud Run URL for visibility.

### Production pipeline (trigger: push of a tag deploy-prod-`<customer-id>`-`<version>`)
1) Checkout repository. Parse tag into:
   - CUSTOMER_ID and VERSION. Enforce regex ^deploy-prod-([a-z0-9-]+)-(.+)$
2) OIDC authenticate to GCP WIF and impersonate ci-terraform@platform.
3) Ensure the image with tag VERSION exists in Artifact Registry. If not:
   - Option A (recommended): Re-tag the exact digest promoted from staging (store image digest in a staging artifact file or release metadata) and push tag VERSION to AR.
   - Option B (simple): Pull the staging tag used for the last successful staging build, tag as VERSION, and push. Note: Less deterministic without digest pinning.
4) Ensure customer project secrets have versions in Secret Manager. Add/update if necessary from GitHub Actions Secrets.
5) Terraform apply for the specific customer:
   - cd infra/envs/customers/${CUSTOMER_ID}
   - terraform init
   - terraform apply -auto-approve -var image_tag=${VERSION}
   - Module updates Cloud Run in the customer’s project to new image tag and ensures runtime SA has Artifact Registry reader.
6) Output Cloud Run URL.

Important production practice: Prefer deploying by image digest (immutable) rather than tag. You can pass image_digest as a variable and set container image to @sha256:... for perfect reproducibility, while still tagging VERSION for human readability.


## Local development on Kubernetes (Minikube or Docker Desktop Kubernetes)
- Build and run the same container image locally.
- Options:
  - Minikube: eval $(minikube docker-env) then docker build -t app:dev . and reference image: app:dev in kustomize overlay.
  - Docker Desktop K8s: use local Docker daemon similarly.
- k8s/base/deployment.yaml should reference env vars matching production, but for secrets:
  - k8s/base/secret.yaml defines placeholders only (no values).
  - k8s/overlays/local/kustomization.yaml overlays:
    - Patch image to app:dev.
    - Create a local Kubernetes Secret from a local .env file (git-ignored).
- The same image name:tag can be pushed to Artifact Registry for remote deployments; locally, you can reuse the tag or define app:dev.
- Optional: Use Skaffold to automate build/push/apply loops with profiles for local.


## Secrets and "build in public" model
- Terraform resources for secrets only include names (metadata). Do not create versions in Terraform to avoid plaintext in state.
- CI uses GitHub Actions Secrets to inject values into GCP Secret Manager via gcloud secrets versions add.
- Local Terraform execution uses a git-ignored .tfvars for any required sensitive variable values that are not secrets themselves, or you can run a one-time CLI to add secret versions.
- Cloud Run services read secrets via env.valueSource.secretKeyRef with version "latest" to pick up secret rotations automatically.


## Lifecycle of a new customer (best-practice workflow)
1) Naming and configuration
   - Choose customer_id (lowercase, hyphenated) to fit GCP naming constraints.
   - Create infra/envs/customers/`<customer-id>`/ with main.tf, variables.tf, backend.tf.
   - Set project_id convention, e.g., proj-`<customer-id>`-prod.
2) Platform-side prep (one-time per repo/organization)
   - Ensure platform env is applied: WIF, Artifact Registry, state bucket.
3) Instantiate customer infrastructure
   - In the customer env, terraform apply once (with create_project=true) to create:
     - GCP project with APIs enabled.
     - Runtime SA.
     - Cloud Run service (will expect image and secrets; if missing, it will wait for deployment).
     - Secret metadata (no versions).
     - Cross-project IAM to allow AR pulls.
4) Add secret versions
   - From CI: store secrets in GitHub Actions Secrets and run a workflow dispatch or on tag to push them into the customer project Secret Manager:
     - gcloud secrets versions add SECRET_NAME --project=proj-`<cust>`-prod --data-file=\<(printenv SECRET_VALUE)
   - Alternatively, locally via .tfvars + a small script (do not commit values).
5) Build and promote image
   - Push to staging branch to build and validate.
   - Promote to production by pushing git tag deploy-prod-`<customer-id>`-`<version>`.
   - Pipeline ensures image:tag exists (or re-tags by digest) and updates Cloud Run via Terraform with image_tag=`<version>`.
6) Ongoing operations
   - Secret rotation: push new secret versions; Cloud Run uses version "latest" automatically.
   - Infra changes: update module or customer env and run Terraform apply via CI with manual approval.


## Key configuration updates and interfaces
- Provider configuration patterns
  - Default provider targets the tenant project; alias provider "platform" targets the platform project for AR IAM and WIF bindings.
- Module interface (essential variables)
  - create_project: bool
  - project_id, org_id, billing_account
  - platform_project_id, region
  - artifact_repo_location, artifact_repo_name, image_name, image_tag
  - cloud_run_service_name, min_instances, max_instances, cpu, memory, concurrency, ingress
  - secrets: map of { secret_id, env_var }
  - deployer_sa_email: grants least-privilege deploy rights for CI
- Outputs
  - cloud_run_url, runtime_service_account_email, project_id
- Backend and remote state
  - Use GCS backend per env with path prefix envs/staging, envs/customers/`<id>` to isolate states.


## Critical architectural decisions and impacts
- Centralized Artifact Registry vs per-project registries
  - Selected centralized repository in platform project for cost and operational simplicity.
  - Impact: cross-project IAM needed; module handles this. Alternative: per-project AR increases isolation but adds cost and overhead.
- Terraform manages Cloud Run vs gcloud run
  - Selected Terraform to keep desired state in code. Impact: image updates require TF apply, which is integrated in CI.
- Secret versions managed outside Terraform
  - Keeps plaintext out of state; requires CI or script to add versions. Impact: reconcile timing so Cloud Run references version "latest" after versions are added.
- OIDC-based CI authentication (WIF) over JSON keys
  - Removes key lifecycle management. Impact: requires initial WIF bootstrap in platform project.
- Project creation inside the module
  - Simplifies onboarding; requires elevated roles for CI SA and careful control over module use. If you prefer, separate project creation into its own “project-factory” module and keep customer-stamp scoped to in-project resources only.
- Image promotion by digest
  - Strongly recommended for reproducibility; tag is for UX. Impact: you'll store and pass digests (e.g., via release notes or artifact file) in production pipelines.


## Minimal short code snippets (illustrative, not full)
- Module usage (staging)
  - module "staging" {
      source = "../../modules/customer-stamp"
      create_project = false
      project_id = var.staging_project_id
      platform_project_id = var.platform_project_id
      region = var.region
      artifact_repo_location = var.artifact_repo_location
      artifact_repo_name = var.artifact_repo_name
      image_name = var.image_name
      image_tag  = var.image_tag
      cloud_run_service_name = "app-staging"
      min_instances = 1
      secrets = {
        "APP_CONFIG" = { secret_id = "app-config", env_var = "APP_CONFIG" }
      }
      deployer_sa_email = var.deployer_sa_email
    }
- Module variable definitions (signature sample)
  - variable "image_name" { type = string }
  - variable "image_tag" { type = string }
  - variable "secrets" {
      type = map(object({ secret_id = string, env_var = string }))
      default = {}
    }
- Cloud Run container image computed inside module
  - local.image = "${var.artifact_repo_location}-docker.pkg.dev/${var.platform_project_id}/${var.artifact_repo_name}/${var.image_name}:${var.image_tag}"


## Actions you can take next
1) Create the repository scaffold and commit it.
2) Implement infra/envs/platform and apply it once to create WIF, AR, and state bucket.
3) Implement modules/customer-stamp with providers (default + alias platform) and the resources described.
4) Implement infra/envs/staging and run terraform apply with an initial image tag to create staging.
5) Implement infra/envs/customers/`<first-customer>` with create_project=true; run apply to create infra.
6) Add GitHub Actions workflows for staging (branch push) and production (tag push) as described.
7) Add scripts to parse tags and to add secret versions from CI.
8) Set GitHub repository secrets for any values you intend to inject into Secret Manager during pipelines.
9) For local dev, set up k8s base + local overlays; ensure you can build app:dev and kubectl apply to your local cluster.