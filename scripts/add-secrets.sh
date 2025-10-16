#!/bin/bash

# Script to add secret versions to GCP Secret Manager
# Usage: ./add-secrets.sh <environment> <secret-file>
# Example: ./add-secrets.sh staging secrets.env
# Example: ./add-secrets.sh customers/acme-llc secrets-acme-llc.env

set -e

ENVIRONMENT="$1"
SECRET_FILE="$2"

if [ -z "$ENVIRONMENT" ] || [ -z "$SECRET_FILE" ]; then
    echo "Usage: $0 <environment> <secret-file>"
    echo ""
    echo "Examples:"
    echo "  $0 staging secrets-staging.env"
    echo "  $0 customers/acme-llc secrets-acme-llc.env"
    echo "  $0 customers/globex secrets-globex.env"
    echo ""
    echo "Secret file format (key=value pairs):"
    echo "  APP_CONFIG={\"env\":\"staging\"}"
    echo "  DATABASE_URL=postgresql://..."
    exit 1
fi

if [ ! -f "$SECRET_FILE" ]; then
    echo "❌ Secret file not found: $SECRET_FILE"
    exit 1
fi

# Determine project ID based on environment
if [ "$ENVIRONMENT" = "staging" ]; then
    echo "📋 Reading staging project ID from terraform.tfvars..."
    if [ -f "infra/envs/staging/terraform.tfvars" ]; then
        PROJECT_ID=$(grep "staging_project_id" infra/envs/staging/terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
    else
        read -p "Enter staging project ID: " PROJECT_ID
    fi
elif [[ "$ENVIRONMENT" =~ ^customers/.+ ]]; then
    # Extract customer name from path (customers/acme-llc -> acme-llc)
    CUSTOMER_NAME="${ENVIRONMENT#customers/}"
    echo "📋 Reading $CUSTOMER_NAME project ID from terraform.tfvars..."
    
    TFVARS_FILE="infra/envs/$ENVIRONMENT/terraform.tfvars"
    if [ -f "$TFVARS_FILE" ]; then
        PROJECT_ID=$(grep "project_id" "$TFVARS_FILE" | head -1 | cut -d'=' -f2 | tr -d ' "')
        echo "  Found project_id in $TFVARS_FILE"
    else
        # Try to read from variables.tf default value
        VARS_FILE="infra/envs/$ENVIRONMENT/variables.tf"
        if [ -f "$VARS_FILE" ]; then
            PROJECT_ID=$(grep -A 2 'variable "project_id"' "$VARS_FILE" | grep 'default' | cut -d'=' -f2 | tr -d ' "')
            echo "  Using default from variables.tf: $PROJECT_ID"
        else
            read -p "Enter project ID for $CUSTOMER_NAME: " PROJECT_ID
        fi
    fi
else
    read -p "Enter project ID for $ENVIRONMENT: " PROJECT_ID
fi

echo "🎯 Target project: $PROJECT_ID"
echo ""

# Mapping of environment variable names to Secret Manager secret IDs
declare -A SECRET_MAP=(
    ["APP_CONFIG"]="app-config"
    ["DATABASE_URL"]="db-url"
    ["WEBSITE_1_CONFIG"]="website-1-config"
    ["WEBSITE_2_CONFIG"]="website-2-config"
    ["CLUSTER_CONFIG"]="cluster-config"
    ["HYBRID_CLOUD_CONFIG"]="hybrid-cloud-config"
    ["NETWORK_CONFIG"]="network-config"
)

# Read and process each secret from file
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    
    # Trim whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    # Skip if no value
    [[ -z "$value" ]] && continue
    
    # Get secret ID from mapping
    SECRET_ID="${SECRET_MAP[$key]}"
    
    if [ -z "$SECRET_ID" ]; then
        echo "⚠️  Unknown secret key: $key (skipping)"
        continue
    fi
    
    echo "🔐 Adding version for secret: $SECRET_ID (from $key)"
    
    # Check if secret exists
    if ! gcloud secrets describe "$SECRET_ID" --project="$PROJECT_ID" &>/dev/null; then
        echo "❌ Secret '$SECRET_ID' does not exist in project '$PROJECT_ID'"
        echo "   Make sure Terraform has been applied to create the secret metadata."
        continue
    fi
    
    # Add secret version
    if echo "$value" | gcloud secrets versions add "$SECRET_ID" --data-file=- --project="$PROJECT_ID" &>/dev/null; then
        echo "✅ Successfully added version for $SECRET_ID"
    else
        echo "❌ Failed to add version for $SECRET_ID"
    fi
    echo ""
done < "$SECRET_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Secret versions added to project: $PROJECT_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To verify:"
echo "  gcloud secrets list --project=$PROJECT_ID"
echo "  gcloud secrets versions list SECRET_NAME --project=$PROJECT_ID"
echo ""
