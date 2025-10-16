# Quick Reference Cheatsheet

## 🎯 Where Do Secrets Go?

### GitHub Secrets (Settings → Secrets and variables → Actions)
```
Infrastructure (both workflows need these):
✓ PLATFORM_PROJECT_ID          Your platform project ID
✓ STAGING_PROJECT_ID            Your staging project ID  
✓ WIF_PROVIDER                  projects/NUM/locations/global/workloadIdentityPools/...
✓ WIF_SERVICE_ACCOUNT           ci-terraform@platform-project.iam.gserviceaccount.com

Application (pushed to GCP Secret Manager):
✓ APP_CONFIG                    App config JSON (all environments)
✓ DATABASE_URL                  Database URL (all environments)
✓ WEBSITE_1_CONFIG              Acme LLC only
✓ WEBSITE_2_CONFIG              Acme LLC only
✓ CLUSTER_CONFIG                Globex only
✓ HYBRID_CLOUD_CONFIG           Globex only
✓ NETWORK_CONFIG                Globex only
```

## 🔐 What is WIF_PROVIDER?
Full resource name of your Workload Identity Provider that allows GitHub to authenticate to GCP.

**Get it:**
```bash
cd infra/envs/platform
../../scripts/get-wif-values.sh
```

**Format:** `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`

## 👤 What is WIF_SERVICE_ACCOUNT?
Email of the service account that GitHub Actions will impersonate to deploy.

**Value:** `ci-terraform@YOUR_PLATFORM_PROJECT_ID.iam.gserviceaccount.com`

## 🚀 Deployment Commands

### Staging
```bash
git checkout staging
git push origin staging
# Triggers: .github/workflows/staging.yml
```

### Acme LLC
```bash
git tag deploy-prod-acme-llc-v1.0.0
git push origin deploy-prod-acme-llc-v1.0.0
# Triggers: .github/workflows/prod-tag.yml
```

### Globex
```bash
git tag deploy-prod-globex-v1.0.0
git push origin deploy-prod-globex-v1.0.0
# Triggers: .github/workflows/prod-tag.yml
```

## 📝 Customer Configurations

### Acme LLC (Customer A - Multi-website deployment)
- **Project:** `proj-acme-llc-prod`
- **Secrets:** WEBSITE_1_CONFIG, WEBSITE_2_CONFIG
- **Example:**
  ```json
  {
    "domain": "site1.acme-llc.com",
    "api_key": "xxx",
    "features": ["checkout", "inventory"]
  }
  ```

### Globex (Customer B - Hybrid cloud, multi-cluster)
- **Project:** `proj-globex-prod`
- **Secrets:** CLUSTER_CONFIG, HYBRID_CLOUD_CONFIG, NETWORK_CONFIG
- **Example:**
  ```json
  {
    "clusters": [
      {"name": "gcp-us", "endpoint": "https://..."},
      {"name": "on-prem", "endpoint": "https://..."}
    ]
  }
  ```

## 🛠️ Useful Scripts

```bash
# Get WIF values for GitHub
./scripts/get-wif-values.sh

# Initialize Git repo
./scripts/init-git-repo.sh

# Add secrets manually (instead of CI/CD)
./scripts/add-secrets.sh staging secrets-staging.env
./scripts/add-secrets.sh customers/acme-llc secrets-acme-llc.env

# Run Terraform
./scripts/tf-wrapper.sh staging plan
./scripts/tf-wrapper.sh customers/acme-llc apply

# Parse deployment tag
./scripts/parse-tag.sh deploy-prod-acme-llc-v1.0.0
```

## 🔍 Verification Commands

```bash
# List secrets in a project
gcloud secrets list --project=PROJECT_ID

# Check secret versions
gcloud secrets versions list SECRET_NAME --project=PROJECT_ID

# Get Cloud Run URL
gcloud run services describe SERVICE_NAME \
  --region=us-central1 \
  --project=PROJECT_ID \
  --format="value(status.url)"

# Test endpoint
curl $(gcloud run services describe app-staging \
  --region=us-central1 \
  --project=STAGING_PROJECT_ID \
  --format="value(status.url)")/health
```

## 📚 Documentation

- **Quick Start:** `docs/QUICK_START.md` - Step-by-step setup guide
- **Secrets Setup:** `docs/SECRETS_SETUP.md` - Everything about secrets
- **Secrets Reference:** `docs/SECRETS_REFERENCE.md` - Which secret goes where
- **Summary:** `docs/SUMMARY.md` - Overview and checklist
- **Architecture:** `README.md` - Full architecture documentation

## ⚡ Quick Setup (Already Did GCP Setup)

```bash
# 1. Get WIF values
cd infra/envs/platform
../../scripts/get-wif-values.sh

# 2. Add those values + all secrets to GitHub
# (Go to GitHub → Settings → Secrets)

# 3. Initialize Git
cd ../..
./scripts/init-git-repo.sh
git remote add origin https://github.com/YOUR_ORG/YOUR_REPO.git
git push -u origin main
git push -u origin staging

# 4. Deploy!
git checkout staging
git push origin staging  # Deploys to staging

git tag deploy-prod-acme-llc-v1.0.0
git push origin deploy-prod-acme-llc-v1.0.0  # Deploys Acme LLC

git tag deploy-prod-globex-v1.0.0
git push origin deploy-prod-globex-v1.0.0  # Deploys Globex
```

## 🐛 Troubleshooting

**GitHub Actions auth fails:**
- Check WIF_PROVIDER includes correct project NUMBER (not ID!)
- Verify WIF_SERVICE_ACCOUNT email is correct
- Ensure repository path in platform Terraform matches GitHub

**Secret not found:**
```bash
# Check secret exists
gcloud secrets list --project=PROJECT_ID

# Check it has versions
gcloud secrets versions list SECRET_NAME --project=PROJECT_ID

# Add version manually
echo "value" | gcloud secrets versions add SECRET_NAME --data-file=- --project=PROJECT_ID
```

**Image not found:**
- Push to staging first to build image
- Or build/push manually for testing
- Verify tag exists in Artifact Registry

## 📁 Project Structure

```
/Users/mux/Developer/GCP/
├── app/                    # Node.js application
├── infra/
│   ├── modules/
│   │   └── customer-stamp/ # Reusable Terraform module
│   └── envs/
│       ├── platform/       # WIF, Artifact Registry
│       ├── staging/        # Staging environment
│       └── customers/
│           ├── acme-llc/  # Multi-website deployment
│           └── globex/    # Hybrid cloud, multi-cluster
├── k8s/                    # Local Kubernetes dev
├── .github/workflows/      # CI/CD pipelines
├── scripts/                # Helper scripts
└── docs/                   # Documentation
```
