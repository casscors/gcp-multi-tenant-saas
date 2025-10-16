# Secrets Reference - Where Everything Goes

## Quick Overview

There are **TWO types** of secrets in this setup:

1. **GitHub Secrets** - Stored in GitHub, used by GitHub Actions workflows
2. **GCP Secrets** - Stored in GCP Secret Manager, used by Cloud Run at runtime

## Secrets Flow

```
GitHub Secrets (in repo settings)
         ↓
    GitHub Actions Workflow
         ↓
GCP Secret Manager (adds versions)
         ↓
    Cloud Run (reads at runtime)
```

---

## 1. GitHub Repository Secrets

**Where to set:** `GitHub Repo → Settings → Secrets and variables → Actions`

### Infrastructure Secrets (Used by GitHub Actions to deploy)

| Secret Name | Example Value | Used By | Purpose |
|-------------|---------------|---------|---------|
| `PLATFORM_PROJECT_ID` | `my-platform-123` | Both workflows | Where Artifact Registry lives |
| `STAGING_PROJECT_ID` | `my-staging-456` | staging.yml | Staging project to deploy to |
| `WIF_PROVIDER` | `projects/123456/locations/global/...` | Both workflows | OIDC authentication |
| `WIF_SERVICE_ACCOUNT` | `ci-terraform@my-platform-123.iam.gserviceaccount.com` | Both workflows | SA to impersonate |

### Application Secrets (Values pushed to GCP Secret Manager)

| Secret Name | Example Value | Goes To | Workflow |
|-------------|---------------|---------|----------|
| `APP_CONFIG` | `{"env":"staging"}` | Staging & Customers | Both |
| `DATABASE_URL` | `postgresql://...` | Staging & Customers | Both |
| `WEBSITE_1_CONFIG` | `{"domain":"site1.com"}` | Acme LLC only | prod-tag.yml |
| `WEBSITE_2_CONFIG` | `{"domain":"site2.com"}` | Acme LLC only | prod-tag.yml |
| `CLUSTER_CONFIG` | `{"clusters":[...]}` | Globex only | prod-tag.yml |
| `HYBRID_CLOUD_CONFIG` | `{"vpn_tunnels":[...]}` | Globex only | prod-tag.yml |
| `NETWORK_CONFIG` | `{"vpc_peering":[...]}` | Globex only | prod-tag.yml |

---

## 2. GCP Secret Manager Secrets

**These are created by Terraform (metadata only), values added by CI/CD or manually.**

### Staging Project Secrets

**Project:** `your-staging-project-id`

| Secret ID (in GCP) | Env Var (in Cloud Run) | Source (GitHub Secret) |
|--------------------|------------------------|------------------------|
| `app-config` | `APP_CONFIG` | `APP_CONFIG` |
| `db-url` | `DATABASE_URL` | `DATABASE_URL` |

**Check:** 
```bash
gcloud secrets list --project=your-staging-project-id
```

### Acme LLC's Project Secrets

**Project:** `proj-acme-llc-prod`

| Secret ID (in GCP) | Env Var (in Cloud Run) | Source (GitHub Secret) |
|--------------------|------------------------|------------------------|
| `app-config` | `APP_CONFIG` | `APP_CONFIG` |
| `db-url` | `DATABASE_URL` | `DATABASE_URL` |
| `website-1-config` | `WEBSITE_1_CONFIG` | `WEBSITE_1_CONFIG` |
| `website-2-config` | `WEBSITE_2_CONFIG` | `WEBSITE_2_CONFIG` |

**Check:**
```bash
gcloud secrets list --project=proj-acme-llc-prod
```

### Globex's Project Secrets

**Project:** `proj-globex-prod`

| Secret ID (in GCP) | Env Var (in Cloud Run) | Source (GitHub Secret) |
|--------------------|------------------------|------------------------|
| `app-config` | `APP_CONFIG` | `APP_CONFIG` |
| `db-url` | `DATABASE_URL` | `DATABASE_URL` |
| `cluster-config` | `CLUSTER_CONFIG` | `CLUSTER_CONFIG` |
| `hybrid-cloud-config` | `HYBRID_CLOUD_CONFIG` | `HYBRID_CLOUD_CONFIG` |
| `network-config` | `NETWORK_CONFIG` | `NETWORK_CONFIG` |

**Check:**
```bash
gcloud secrets list --project=proj-globex-prod
```

---

## 3. WIF (Workload Identity Federation) Values

### WIF_PROVIDER

**What it is:** The full resource name of your Workload Identity Pool Provider

**Format:**
```
projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
```

**Your actual value (example):**
```
projects/123456789012/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
```

**How to get it:**
```bash
cd infra/envs/platform
../../scripts/get-wif-values.sh
```

**Or manually:**
```bash
gcloud iam workload-identity-pools providers describe github-actions-provider \
  --workload-identity-pool=github-actions-pool \
  --location=global \
  --project=YOUR_PLATFORM_PROJECT_ID \
  --format="value(name)"
```

### WIF_SERVICE_ACCOUNT

**What it is:** The email of your CI/CD service account

**Format:**
```
ACCOUNT_ID@PROJECT_ID.iam.gserviceaccount.com
```

**Your actual value (example):**
```
ci-terraform@my-platform-123.iam.gserviceaccount.com
```

**Components:**
- Account ID: `ci-terraform` (defined in platform/main.tf)
- Project ID: Your platform project ID

---

## 4. How Secrets Are Used in Workflows

### staging.yml Workflow

```yaml
# Uses these GitHub Secrets:
- PLATFORM_PROJECT_ID   # Where to push images
- STAGING_PROJECT_ID    # Where to deploy Cloud Run
- WIF_PROVIDER         # To authenticate
- WIF_SERVICE_ACCOUNT  # To impersonate
- APP_CONFIG           # Added to Secret Manager
- DATABASE_URL         # Added to Secret Manager

# Workflow steps:
1. Authenticate to GCP using WIF
2. Build Docker image
3. Push to Artifact Registry in platform project
4. Add secret versions to staging project's Secret Manager
5. Run Terraform to deploy Cloud Run in staging project
```

### prod-tag.yml Workflow

```yaml
# Uses these GitHub Secrets:
- PLATFORM_PROJECT_ID       # Where images are stored
- WIF_PROVIDER             # To authenticate
- WIF_SERVICE_ACCOUNT      # To impersonate
- APP_CONFIG               # Added to customer project
- DATABASE_URL             # Added to customer project
- WEBSITE_1_CONFIG         # Acme LLC only
- WEBSITE_2_CONFIG         # Acme LLC only
- CLUSTER_CONFIG           # Globex only
- HYBRID_CLOUD_CONFIG      # Globex only
- NETWORK_CONFIG           # Globex only

# Workflow steps:
1. Parse tag: deploy-prod-<customer-id>-<version>
2. Authenticate to GCP using WIF
3. Verify image exists in Artifact Registry
4. Add customer-specific secret versions
5. Run Terraform to deploy Cloud Run in customer project
```

---

## 5. Example Secret Values

### For Staging

```bash
# APP_CONFIG (GitHub Secret)
{"environment":"staging","log_level":"debug","features":{"new_ui":true}}

# DATABASE_URL (GitHub Secret)
postgresql://staging_user:password@10.0.1.5:5432/staging_db
```

### For Acme LLC (Multi-website Deployment)

```bash
# WEBSITE_1_CONFIG (GitHub Secret)
{"domain":"shop.acme-llc.com","api_key":"acme-shop-api-key-abc123","database":"acme_shop","features":["checkout","inventory","reviews"]}

# WEBSITE_2_CONFIG (GitHub Secret)
{"domain":"blog.acme-llc.com","api_key":"acme-blog-api-key-xyz789","database":"acme_blog","features":["comments","posts","media"]}
```

**How Acme LLC's app uses these:**
```javascript
// In app/src/index.js
const website1Config = JSON.parse(process.env.WEBSITE_1_CONFIG || '{}');
const website2Config = JSON.parse(process.env.WEBSITE_2_CONFIG || '{}');

app.use((req, res, next) => {
  if (req.hostname === website1Config.domain) {
    req.siteConfig = website1Config;
    req.database = website1Config.database;
  } else if (req.hostname === website2Config.domain) {
    req.siteConfig = website2Config;
    req.database = website2Config.database;
  }
  next();
});
```

### For Globex (Hybrid Cloud, Multi-cluster)

```bash
# CLUSTER_CONFIG (GitHub Secret)
{"clusters":[{"name":"gcp-us-central1","endpoint":"https://35.123.45.67","region":"us-central1","type":"gke"},{"name":"gcp-europe-west1","endpoint":"https://34.98.76.54","region":"europe-west1","type":"gke"},{"name":"on-prem-dc1","endpoint":"https://10.10.1.100:6443","location":"datacenter-1","type":"on-premises"}]}

# HYBRID_CLOUD_CONFIG (GitHub Secret)
{"vpn_tunnels":[{"name":"gcp-to-dc1","peer_ip":"203.0.113.100","shared_secret_ref":"vpn-secret-1"}],"interconnects":[{"name":"int-dc1","bandwidth":"10Gbps"}],"on_prem_cidr":"10.0.0.0/8","cloud_cidr":"172.16.0.0/16"}

# NETWORK_CONFIG (GitHub Secret)
{"vpc_peering":[{"network":"gcp-prod-vpc","peer":"gcp-mgmt-vpc"},{"network":"gcp-prod-vpc","peer":"on-prem-vpc"}],"firewall_rules":[{"name":"allow-cluster-communication","ports":["443","6443","10250"],"sources":["10.0.0.0/8","172.16.0.0/16"]}],"private_service_connect":{"enabled":true,"endpoints":["memorystore","cloud-sql"]}}
```

---

## 6. Testing Secret Access

### From Cloud Run

```bash
# Get Cloud Run service URL
URL=$(gcloud run services describe app-staging \
  --region=us-central1 \
  --project=YOUR_STAGING_PROJECT_ID \
  --format="value(status.url)")

# Test endpoint that shows environment
curl $URL

# Should return something like:
{
  "message": "GCP Multi-tenant Application",
  "version": "1.0.0",
  "environment": "development",
  "customer": "unknown"
}
```

### From Local Development

```bash
# Create local .env file (git-ignored)
cat > .env << EOF
APP_CONFIG={"environment":"local","debug":true}
DATABASE_URL=postgresql://localhost:5432/local_db
EOF

# Run locally
cd app
npm install
npm start

# Test
curl http://localhost:3000/health
```

---

## 7. Security Checklist

- [ ] ✅ All `*.tfvars` files are git-ignored
- [ ] ✅ No secrets in GitHub repository code
- [ ] ✅ GitHub Secrets set with appropriate values
- [ ] ✅ WIF configured (no service account keys!)
- [ ] ✅ Secret Manager has appropriate IAM permissions
- [ ] ✅ Cloud Run runtime SA has `secretmanager.secretAccessor` role
- [ ] ✅ Branch protection enabled on main/staging branches
- [ ] ✅ Cloud Audit Logs enabled for Secret Manager
- [ ] 🔄 Plan secret rotation schedule
- [ ] 🔄 Set up alerts for failed secret access

---

## 8. Common Commands Reference

```bash
# List all secrets in a project
gcloud secrets list --project=PROJECT_ID

# List versions of a specific secret
gcloud secrets versions list SECRET_NAME --project=PROJECT_ID

# Add a new secret version
echo "new-value" | gcloud secrets versions add SECRET_NAME --data-file=- --project=PROJECT_ID

# Get latest secret value
gcloud secrets versions access latest --secret=SECRET_NAME --project=PROJECT_ID

# Describe a secret (metadata only)
gcloud secrets describe SECRET_NAME --project=PROJECT_ID

# Grant access to a secret
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/secretmanager.secretAccessor" \
  --project=PROJECT_ID
```
