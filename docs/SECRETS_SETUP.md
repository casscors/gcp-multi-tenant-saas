# Secrets Setup Guide

This guide explains where and how to set secrets for your GCP multi-tenant deployment.

## Table of Contents
1. [GitHub Repository Secrets](#github-repository-secrets)
2. [GCP Secret Manager Secrets](#gcp-secret-manager-secrets)
3. [Workload Identity Federation (WIF)](#workload-identity-federation-wif)
4. [Customer-Specific Secrets](#customer-specific-secrets)

---

## GitHub Repository Secrets

These secrets are set in your GitHub repository settings and used by GitHub Actions workflows.

### Location
Go to: `GitHub Repo → Settings → Secrets and variables → Actions → New repository secret`

### Required GitHub Secrets

#### Platform & Infrastructure Secrets
```
PLATFORM_PROJECT_ID
  Value: your-platform-project-id
  Description: The GCP project ID for your platform (where Artifact Registry lives)

STAGING_PROJECT_ID
  Value: your-staging-project-id
  Description: The GCP project ID for staging environment

WIF_PROVIDER
  Value: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
  Description: Full resource name of your Workload Identity Provider
  How to get: See "Getting WIF Values" section below

WIF_SERVICE_ACCOUNT
  Value: ci-terraform@your-platform-project-id.iam.gserviceaccount.com
  Description: Email of the CI service account that GitHub Actions will impersonate
```

#### Application Secrets (Staging)
```
APP_CONFIG
  Value: {"environment": "staging", "feature_flags": {...}}
  Description: Application configuration JSON for staging

DATABASE_URL
  Value: postgresql://user:pass@host:5432/dbname
  Description: Database connection string for staging
```

#### Customer-Specific Secrets (Acme LLC - Multi-website deployment)
```
WEBSITE_1_CONFIG
  Value: {"domain": "site1.acme-llc.com", "api_key": "xxx"}
  Description: Configuration for Acme LLC's first website

WEBSITE_2_CONFIG
  Value: {"domain": "site2.acme-llc.com", "api_key": "yyy"}
  Description: Configuration for Acme LLC's second website
```

#### Customer-Specific Secrets (Globex - Hybrid cloud, multi-cluster)
```
CLUSTER_CONFIG
  Value: {"clusters": [...], "endpoints": [...]}
  Description: Kubernetes cluster configuration for Globex

HYBRID_CLOUD_CONFIG
  Value: {"on_prem_endpoints": [...], "vpn_config": {...}}
  Description: Hybrid cloud connectivity configuration

NETWORK_CONFIG
  Value: {"vpc_peering": [...], "firewall_rules": [...]}
  Description: Network configuration for multi-cluster setup
```

---

## GCP Secret Manager Secrets

These are the actual secrets stored in GCP Secret Manager. GitHub Actions will push secret **versions** (values) to these secret **resources** (metadata).

### How They Work
1. **Terraform creates the secret metadata** (empty secret resource)
2. **CI/CD or manual process adds secret versions** (actual values)
3. **Cloud Run reads from version "latest"** automatically

### For Each Environment

#### Staging Project
```bash
# List secrets in staging project
gcloud secrets list --project=your-staging-project-id

# Expected secrets (created by Terraform):
# - app-config
# - db-url
```

#### Customer Projects
```bash
# Acme LLC's project
gcloud secrets list --project=proj-acme-llc-prod

# Expected secrets:
# - app-config
# - db-url
# - website-1-config
# - website-2-config

# Globex's project
gcloud secrets list --project=proj-globex-prod

# Expected secrets:
# - app-config
# - db-url
# - cluster-config
# - hybrid-cloud-config
# - network-config
```

### Manual Secret Version Creation

If you need to add secret versions manually (outside CI/CD):

```bash
# For staging
echo '{"environment": "staging"}' | \
  gcloud secrets versions add app-config \
  --data-file=- \
  --project=your-staging-project-id

# For Acme LLC
echo '{"domain": "site1.acme-llc.com"}' | \
  gcloud secrets versions add website-1-config \
  --data-file=- \
  --project=proj-acme-llc-prod

# For Globex
echo '{"clusters": ["cluster1", "cluster2"]}' | \
  gcloud secrets versions add cluster-config \
  --data-file=- \
  --project=proj-globex-prod
```

---

## Workload Identity Federation (WIF)

WIF allows GitHub Actions to authenticate to GCP without storing service account keys.

### What is WIF_PROVIDER?

The **WIF Provider** is the OIDC identity provider that GitHub uses to authenticate.

**Format:**
```
projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
```

**From your Terraform (infra/envs/platform/main.tf):**
- Pool ID: `github-actions-pool`
- Provider ID: `github-actions-provider`

### What is WIF_SERVICE_ACCOUNT?

The **WIF Service Account** is the GCP service account that GitHub Actions will impersonate.

**From your Terraform (infra/envs/platform/main.tf):**
- Account ID: `ci-terraform`
- Email: `ci-terraform@your-platform-project-id.iam.gserviceaccount.com`

### Getting WIF Values

#### Step 1: Get your Platform Project Number
```bash
# Get project number (not project ID!)
gcloud projects describe your-platform-project-id --format="value(projectNumber)"
```

#### Step 2: Get WIF Provider full name
```bash
# After applying platform Terraform, run:
gcloud iam workload-identity-pools providers describe github-actions-provider \
  --workload-identity-pool=github-actions-pool \
  --location=global \
  --project=your-platform-project-id \
  --format="value(name)"
```

This will output something like:
```
projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
```

#### Step 3: Get Service Account Email
```bash
# After applying platform Terraform, run:
gcloud iam service-accounts describe ci-terraform@your-platform-project-id.iam.gserviceaccount.com \
  --project=your-platform-project-id \
  --format="value(email)"
```

### Alternative: Use Terraform Outputs

Add these to `infra/envs/platform/main.tf` (or outputs.tf):

```hcl
output "wif_provider_name" {
  description = "Full WIF provider name for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "wif_service_account_email" {
  description = "CI service account email for GitHub Actions"
  value       = google_service_account.ci_terraform.email
}
```

Then after `terraform apply`:
```bash
cd infra/envs/platform
terraform output wif_provider_name
terraform output wif_service_account_email
```

---

## Customer-Specific Secrets

### Acme LLC (Multi-website Deployment)

**Scenario:** Acme LLC needs separate configurations for two different websites, both running in the same Cloud Run service.

**Secrets to set in GitHub:**
- `WEBSITE_1_CONFIG`: First website configuration
- `WEBSITE_2_CONFIG`: Second website configuration

**Example values:**
```json
// WEBSITE_1_CONFIG
{
  "domain": "shop.acme-llc.com",
  "api_key": "acme-shop-api-key",
  "features": ["checkout", "inventory"],
  "database": "acme_shop_db"
}

// WEBSITE_2_CONFIG
{
  "domain": "blog.acme-llc.com",
  "api_key": "acme-blog-api-key",
  "features": ["comments", "posts"],
  "database": "acme_blog_db"
}
```

**In your application code (app/src/index.js):**
```javascript
const website1Config = JSON.parse(process.env.WEBSITE_1_CONFIG || '{}');
const website2Config = JSON.parse(process.env.WEBSITE_2_CONFIG || '{}');

// Route based on domain
app.use((req, res, next) => {
  if (req.hostname === website1Config.domain) {
    req.siteConfig = website1Config;
  } else if (req.hostname === website2Config.domain) {
    req.siteConfig = website2Config;
  }
  next();
});
```

### Globex (Hybrid Cloud, Multi-cluster)

**Scenario:** Globex has multiple Kubernetes clusters across on-prem and cloud, requiring complex networking and cluster configuration.

**Secrets to set in GitHub:**
- `CLUSTER_CONFIG`: Kubernetes cluster endpoints and credentials
- `HYBRID_CLOUD_CONFIG`: On-prem to cloud connectivity
- `NETWORK_CONFIG`: VPC peering, firewall rules, etc.

**Example values:**
```json
// CLUSTER_CONFIG
{
  "clusters": [
    {
      "name": "gcp-us-central",
      "endpoint": "https://34.67.89.123",
      "region": "us-central1"
    },
    {
      "name": "on-prem-dc1",
      "endpoint": "https://10.0.1.100:6443",
      "location": "on-premises"
    }
  ]
}

// HYBRID_CLOUD_CONFIG
{
  "vpn_tunnels": [
    {"name": "gcp-to-onprem-1", "peer_ip": "203.0.113.1"}
  ],
  "interconnects": ["int-1", "int-2"],
  "on_prem_cidr": "10.0.0.0/8"
}

// NETWORK_CONFIG
{
  "vpc_peering": [
    {"network": "gcp-prod-vpc", "peer": "gcp-mgmt-vpc"}
  ],
  "firewall_rules": [
    {"name": "allow-cluster-internal", "ports": ["443", "6443"]}
  ]
}
```

---

## Quick Setup Checklist

### 1. Platform Setup
- [ ] Apply platform Terraform: `cd infra/envs/platform && terraform apply`
- [ ] Get WIF provider name: `terraform output wif_provider_name`
- [ ] Get CI SA email: `terraform output wif_service_account_email`
- [ ] Set `PLATFORM_PROJECT_ID` in GitHub
- [ ] Set `WIF_PROVIDER` in GitHub
- [ ] Set `WIF_SERVICE_ACCOUNT` in GitHub

### 2. Staging Setup
- [ ] Set `STAGING_PROJECT_ID` in GitHub
- [ ] Set `APP_CONFIG` in GitHub (for staging)
- [ ] Set `DATABASE_URL` in GitHub (for staging)
- [ ] Apply staging Terraform: `cd infra/envs/staging && terraform apply`

### 3. Acme LLC (Customer A) Setup
- [ ] Set `WEBSITE_1_CONFIG` in GitHub
- [ ] Set `WEBSITE_2_CONFIG` in GitHub
- [ ] Apply customer Terraform: `cd infra/envs/customers/acme-llc && terraform apply`

### 4. Globex (Customer B) Setup
- [ ] Set `CLUSTER_CONFIG` in GitHub
- [ ] Set `HYBRID_CLOUD_CONFIG` in GitHub
- [ ] Set `NETWORK_CONFIG` in GitHub
- [ ] Apply customer Terraform: `cd infra/envs/customers/globex && terraform apply`

### 5. Test Deployments
- [ ] Push to `staging` branch to trigger staging deployment
- [ ] Tag `deploy-prod-acme-llc-v1.0.0` to deploy Acme LLC
- [ ] Tag `deploy-prod-globex-v1.0.0` to deploy Globex

---

## Troubleshooting

### "Permission denied" when GitHub Actions tries to authenticate
- Check that `WIF_PROVIDER` includes your correct project number
- Verify the GitHub repository is correctly bound in the WIF provider
- Ensure the service account has the necessary roles

### "Secret not found" errors in Cloud Run
- Verify secret metadata exists: `gcloud secrets list --project=PROJECT_ID`
- Check if secret has versions: `gcloud secrets versions list SECRET_NAME --project=PROJECT_ID`
- Ensure runtime service account has `secretmanager.secretAccessor` role

### Secrets not updating in Cloud Run
- Cloud Run uses version "latest" - add a new version to update
- Force new revision: `gcloud run services update SERVICE_NAME --update-env-vars=FORCE_UPDATE=$(date +%s)`

---

## Security Best Practices

1. **Never commit secrets to Git** - use `.gitignore` to exclude `*.tfvars`
2. **Rotate secrets regularly** - add new versions to Secret Manager
3. **Use least privilege** - grant minimal IAM roles needed
4. **Audit secret access** - enable Cloud Audit Logs for Secret Manager
5. **Use different secrets per environment** - don't reuse staging secrets in production
