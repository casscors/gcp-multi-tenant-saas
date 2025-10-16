#!/bin/bash

# Script to get WIF (Workload Identity Federation) values for GitHub Actions
# Run this after applying the platform Terraform configuration

set -e

echo "🔍 Getting Workload Identity Federation values..."
echo ""

# Get platform project ID from terraform if in platform directory
if [ -f "terraform.tfvars" ]; then
    PLATFORM_PROJECT_ID=$(grep "platform_project_id" terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
else
    read -p "Enter your platform project ID: " PLATFORM_PROJECT_ID
fi

echo "Platform Project ID: $PLATFORM_PROJECT_ID"
echo ""

# Get project number
echo "📊 Getting project number..."
PROJECT_NUMBER=$(gcloud projects describe "$PLATFORM_PROJECT_ID" --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"
echo ""

# Get WIF provider full name
echo "🔐 Getting WIF Provider name..."
WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe github-actions-provider \
  --workload-identity-pool=github-actions-pool \
  --location=global \
  --project="$PLATFORM_PROJECT_ID" \
  --format="value(name)" 2>/dev/null || echo "")

if [ -z "$WIF_PROVIDER" ]; then
    echo "⚠️  WIF Provider not found. Make sure you've applied the platform Terraform configuration."
    WIF_PROVIDER="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider"
    echo "Expected WIF Provider: $WIF_PROVIDER"
else
    echo "WIF Provider: $WIF_PROVIDER"
fi
echo ""

# Get CI service account email
echo "👤 Getting CI Service Account email..."
CI_SA_EMAIL="ci-terraform@${PLATFORM_PROJECT_ID}.iam.gserviceaccount.com"
SA_EXISTS=$(gcloud iam service-accounts describe "$CI_SA_EMAIL" \
  --project="$PLATFORM_PROJECT_ID" \
  --format="value(email)" 2>/dev/null || echo "")

if [ -z "$SA_EXISTS" ]; then
    echo "⚠️  Service Account not found. Make sure you've applied the platform Terraform configuration."
    echo "Expected Service Account: $CI_SA_EMAIL"
else
    echo "Service Account: $CI_SA_EMAIL"
fi
echo ""

# Output summary for GitHub Secrets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 GitHub Repository Secrets Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Add these secrets to your GitHub repository:"
echo "(Settings → Secrets and variables → Actions → New repository secret)"
echo ""
echo "PLATFORM_PROJECT_ID"
echo "$PLATFORM_PROJECT_ID"
echo ""
echo "WIF_PROVIDER"
echo "$WIF_PROVIDER"
echo ""
echo "WIF_SERVICE_ACCOUNT"
echo "$CI_SA_EMAIL"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Save to file for reference
OUTPUT_FILE="wif-github-secrets.txt"
cat > "$OUTPUT_FILE" << EOF
GitHub Repository Secrets for GCP WIF
Generated: $(date)

PLATFORM_PROJECT_ID
$PLATFORM_PROJECT_ID

WIF_PROVIDER
$WIF_PROVIDER

WIF_SERVICE_ACCOUNT
$CI_SA_EMAIL

To add these to GitHub:
1. Go to your GitHub repository
2. Click Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret with the name and value above
EOF

echo ""
echo "✅ Values saved to: $OUTPUT_FILE"
echo ""
