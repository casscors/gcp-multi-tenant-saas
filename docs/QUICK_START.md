# Quick Start Guide

This guide walks you through setting up the GCP multi-tenant infrastructure from scratch.

## Prerequisites

### Install and Configure gcloud CLI

If you haven't already installed the gcloud CLI:

**macOS:**
```bash
brew install google-cloud-sdk
```

**Linux:**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows:**
Download and install from: https://cloud.google.com/sdk/docs/install

### Initialize gcloud

```bash
# Initialize gcloud and authenticate
gcloud init
gcloud auth login

# Set up Application Default Credentials (needed for Terraform)
gcloud auth application-default login
```

### Get your Organization and Billing Info

```bash
# List organizations (you need the org ID)
gcloud organizations list

# List billing accounts
gcloud billing accounts list

# Set your default project (if you have one)
gcloud config set project YOUR_PROJECT_ID
```

### Create GCP Projects

You'll need to create three projects:
1. **Platform project** - For Artifact Registry, WIF, and Terraform state
2. **Staging project** - For staging deployments
3. **Customer projects** - One for each production customer (can be created by Terraform later)

```bash
# Create platform project
gcloud projects create YOUR-PLATFORM-PROJECT-ID --name="Platform" --organization=YOUR_ORG_ID

# Link billing account
gcloud billing projects link YOUR-PLATFORM-PROJECT-ID --billing-account=YOUR_BILLING_ACCOUNT_ID

# Create staging project
gcloud projects create YOUR-STAGING-PROJECT-ID --name="Staging" --organization=YOUR_ORG_ID
gcloud billing projects link YOUR-STAGING-PROJECT-ID --billing-account=YOUR_BILLING_ACCOUNT_ID
```

---

## Step 1: Customize for Your Customers

Before getting started, customize the repository for your specific customers:

```bash
# Copy the customer configuration template
cp .customer-config.example .customer-config

# Edit with your customer information
vim .customer-config

# Run the setup script to customize the repo
./scripts/setup-customers.sh
```

This will replace the generic customer names (acme-llc, globex) with your actual customer identifiers throughout the repository.

---

## Step 2: Apply Platform Terraform

```bash
cd infra/envs/platform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
vim terraform.tfvars

# Initialize and apply
terraform init
terraform apply
```

---

## Step 3: Get WIF Values for GitHub

Run this script to get the values you need for GitHub Secrets:

```bash
cd infra/envs/platform
./../../scripts/get-wif-values.sh
```

This will output:
- `PLATFORM_PROJECT_ID`
- `WIF_PROVIDER` (full resource name)
- `WIF_SERVICE_ACCOUNT` (email address)

## Step 4: Set GitHub Repository Secrets

Go to your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

### Core Infrastructure Secrets (Required)
```
PLATFORM_PROJECT_ID = your-platform-project-id
WIF_PROVIDER = projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
WIF_SERVICE_ACCOUNT = ci-terraform@your-platform-project-id.iam.gserviceaccount.com
STAGING_PROJECT_ID = your-staging-project-id
```

### Application Secrets for Staging
```
APP_CONFIG = {"environment":"staging","features":["feature1","feature2"]}
DATABASE_URL = postgresql://user:pass@host:5432/staging_db
```

### Acme LLC's Customer Secrets (Multi-website deployment)
```
WEBSITE_1_CONFIG = {"domain":"site1.acme-llc.com","api_key":"your-key"}
WEBSITE_2_CONFIG = {"domain":"site2.acme-llc.com","api_key":"your-key"}
```

### Globex's Customer Secrets (Hybrid cloud, multi-cluster)
```
CLUSTER_CONFIG = {"clusters":[{"name":"cluster1","endpoint":"https://..."}]}
HYBRID_CLOUD_CONFIG = {"vpn_tunnels":[{"name":"tunnel1"}]}
NETWORK_CONFIG = {"vpc_peering":[],"firewall_rules":[]}
```

## Step 5: Initialize Git Repository

```bash
# Run the init script
./scripts/init-git-repo.sh

# Add your GitHub remote
git remote add origin https://github.com/YOUR_ORG/YOUR_REPO.git

# Push to GitHub
git push -u origin main
git push -u origin staging
```

## Step 6: Manual Secret Setup (Alternative to CI/CD)

If you want to add secrets manually instead of through GitHub Actions:

```bash
# Create a secrets file (DO NOT COMMIT THIS!)
cp secrets.env.example secrets-staging.env
# Edit secrets-staging.env with your actual values

# Add secrets to staging
./scripts/add-secrets.sh staging secrets-staging.env

# Add secrets to Acme LLC
cp secrets.env.example secrets-acme-llc.env
# Edit secrets-acme-llc.env with Acme LLC's actual values
./scripts/add-secrets.sh customers/acme-llc secrets-acme-llc.env

# Add secrets to Globex
cp secrets.env.example secrets-globex.env
# Edit secrets-globex.env with Globex's actual values
./scripts/add-secrets.sh customers/globex secrets-globex.env
```

## Step 7: Deploy to Staging

Option A: Via GitHub Actions (Recommended)
```bash
# Make a change
git checkout staging
echo "test" >> app/src/index.js
git add .
git commit -m "Test staging deployment"
git push origin staging

# Watch the GitHub Actions workflow run
# It will build, push image, and deploy to Cloud Run
```

Option B: Manual Terraform
```bash
# Build and push image manually
cd app
docker build -t us-central1-docker.pkg.dev/YOUR_PLATFORM_PROJECT/apps/gcp-app:staging-test .
docker push us-central1-docker.pkg.dev/YOUR_PLATFORM_PROJECT/apps/gcp-app:staging-test

# Deploy with Terraform
cd ../infra/envs/staging
terraform apply -var="image_tag=staging-test"
```

## Step 8: Deploy to Production (Customers)

### Deploy to Acme LLC
```bash
# Tag a release
git tag deploy-prod-acme-llc-v1.0.0
git push origin deploy-prod-acme-llc-v1.0.0

# GitHub Actions will:
# 1. Parse the tag (customer=acme-llc, version=v1.0.0)
# 2. Verify image exists in Artifact Registry
# 3. Add secret versions to Acme LLC's project
# 4. Run Terraform to deploy Cloud Run
```

### Deploy to Globex
```bash
git tag deploy-prod-globex-v1.0.0
git push origin deploy-prod-globex-v1.0.0
```

## Understanding WIF_PROVIDER and WIF_SERVICE_ACCOUNT

### WIF_PROVIDER
This is the **full resource name** of your Workload Identity Pool Provider.

**Format:**
```
projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
```

**What it does:**
- Allows GitHub Actions to authenticate to GCP using OIDC tokens
- No service account keys needed!
- GitHub proves its identity via JWT tokens

**Your values (from Terraform):**
- Pool ID: `github-actions-pool`
- Provider ID: `github-actions-provider`
- Full name: `projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`

### WIF_SERVICE_ACCOUNT
This is the **email** of the GCP service account that GitHub Actions will impersonate.

**Format:**
```
ACCOUNT_ID@PROJECT_ID.iam.gserviceaccount.com
```

**What it does:**
- GitHub Actions assumes this identity
- This SA has all the permissions to deploy (run.admin, artifactregistry.admin, etc.)
- Permissions are granted via IAM in your platform Terraform

**Your value (from Terraform):**
```
ci-terraform@YOUR_PLATFORM_PROJECT_ID.iam.gserviceaccount.com
```

## Verification Commands

### Check if secrets exist
```bash
# Staging
gcloud secrets list --project=YOUR_STAGING_PROJECT_ID

# Acme LLC
gcloud secrets list --project=proj-acme-llc-prod

# Globex
gcloud secrets list --project=proj-globex-prod
```

### Check if secrets have versions
```bash
gcloud secrets versions list app-config --project=YOUR_PROJECT_ID
```

### Check Cloud Run service
```bash
gcloud run services describe app-staging --region=us-central1 --project=YOUR_STAGING_PROJECT_ID
```

### Test Cloud Run endpoint
```bash
# Get URL
URL=$(gcloud run services describe app-staging --region=us-central1 --project=YOUR_STAGING_PROJECT_ID --format="value(status.url)")

# Test it
curl $URL
curl $URL/health
curl $URL/api/status
```

## Troubleshooting

### GitHub Actions fails with "permission denied"
1. Check your WIF_PROVIDER value includes the correct project number
2. Verify WIF_SERVICE_ACCOUNT email is correct
3. Make sure the repository path in platform Terraform matches your GitHub repo

### "Secret not found" in Cloud Run
1. Verify secret metadata exists: `gcloud secrets list --project=PROJECT_ID`
2. Check secret has versions: `gcloud secrets versions list SECRET_NAME --project=PROJECT_ID`
3. Add version: `echo "value" | gcloud secrets versions add SECRET_NAME --data-file=- --project=PROJECT_ID`

### Image not found in Artifact Registry
1. Build and push manually first for testing
2. Or push to staging branch to let CI build it
3. Then reference that image tag in production deployment

## Next Steps

1. ✅ Set up GitHub secrets (Step 2)
2. ✅ Initialize Git repository (Step 3)
3. ✅ Add GCP secret versions (Step 4)
4. ✅ Deploy to staging (Step 5)
5. ✅ Deploy to customers (Step 6)
6. 📚 Read `docs/SECRETS_SETUP.md` for detailed info
7. 🔒 Set up branch protection rules on GitHub
8. 📊 Enable Cloud Monitoring alerts
9. 🔄 Set up secret rotation schedule
