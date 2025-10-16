#!/bin/bash

# Customer Setup Script
# This script customizes the repository for your specific customers
# It replaces generic names (acme-llc, globex) with your actual customer identifiers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.customer-config"

echo "=================================================="
echo "🏢 Customer Configuration Setup"
echo "=================================================="
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: .customer-config"
    echo ""
    echo "To get started:"
    echo "  1. Copy the example: cp .customer-config.example .customer-config"
    echo "  2. Edit .customer-config with your customer information"
    echo "  3. Run this script again: ./scripts/setup-customers.sh"
    echo ""
    exit 1
fi

# Source the configuration
echo "📋 Loading configuration from .customer-config..."
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Validate required variables
REQUIRED_VARS=(
    "CUSTOMER_A_NAME"
    "CUSTOMER_A_PROJECT"
    "CUSTOMER_B_NAME"
    "CUSTOMER_B_PROJECT"
    "PLATFORM_PROJECT_ID"
    "STAGING_PROJECT_ID"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required variable $var is not set in .customer-config"
        exit 1
    fi
done

echo "✅ Configuration loaded successfully"
echo ""

# Display what will be changed
echo "📝 Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Customer A (replacing 'acme-llc'):"
echo "  Name:    $CUSTOMER_A_NAME"
echo "  Project: $CUSTOMER_A_PROJECT"
echo ""
echo "Customer B (replacing 'globex'):"
echo "  Name:    $CUSTOMER_B_NAME"
echo "  Project: $CUSTOMER_B_PROJECT"
echo ""
echo "Platform:"
echo "  Project: $PLATFORM_PROJECT_ID"
echo "  Staging: $STAGING_PROJECT_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Confirm before proceeding
read -p "⚠️  This will modify files in your repository. Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled"
    exit 0
fi

echo ""
echo "🔧 Starting customization..."
echo ""

# Function to replace text in files
replace_in_files() {
    local search="$1"
    local replace="$2"
    local pattern="$3"
    
    echo "  Replacing '$search' → '$replace'"
    
    # Find all files matching pattern, exclude .git, node_modules, etc.
    find "$REPO_ROOT" -type f \( -name "$pattern" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/.terraform/*" \
        -not -path "*/dist/*" \
        -print0 | while IFS= read -r -d '' file; do
        
        # Use sed to replace (macOS compatible)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|$search|$replace|g" "$file"
        else
            sed -i "s|$search|$replace|g" "$file"
        fi
    done
}

# 1. Rename customer directories
echo "📁 Step 1: Renaming customer directories..."
if [ -d "$REPO_ROOT/infra/envs/customers/acme-llc" ]; then
    mv "$REPO_ROOT/infra/envs/customers/acme-llc" "$REPO_ROOT/infra/envs/customers/$CUSTOMER_A_NAME"
    echo "  ✅ Renamed acme-llc → $CUSTOMER_A_NAME"
fi

if [ -d "$REPO_ROOT/infra/envs/customers/globex" ]; then
    mv "$REPO_ROOT/infra/envs/customers/globex" "$REPO_ROOT/infra/envs/customers/$CUSTOMER_B_NAME"
    echo "  ✅ Renamed globex → $CUSTOMER_B_NAME"
fi
echo ""

# 2. Replace in documentation files
echo "📚 Step 2: Updating documentation..."
replace_in_files "acme-llc" "$CUSTOMER_A_NAME" "*.md"
replace_in_files "globex" "$CUSTOMER_B_NAME" "*.md"
replace_in_files "proj-acme-llc-prod" "$CUSTOMER_A_PROJECT" "*.md"
replace_in_files "proj-globex-prod" "$CUSTOMER_B_PROJECT" "*.md"
echo "  ✅ Documentation updated"
echo ""

# 3. Replace in Terraform files
echo "🏗️  Step 3: Updating Terraform files..."
replace_in_files "acme-llc" "$CUSTOMER_A_NAME" "*.tf"
replace_in_files "globex" "$CUSTOMER_B_NAME" "*.tf"
replace_in_files "proj-acme-llc-prod" "$CUSTOMER_A_PROJECT" "*.tf"
replace_in_files "proj-globex-prod" "$CUSTOMER_B_PROJECT" "*.tf"
replace_in_files "acme-llc" "$CUSTOMER_A_NAME" "*.tfvars.example"
replace_in_files "globex" "$CUSTOMER_B_NAME" "*.tfvars.example"
replace_in_files "proj-acme-llc-prod" "$CUSTOMER_A_PROJECT" "*.tfvars.example"
replace_in_files "proj-globex-prod" "$CUSTOMER_B_PROJECT" "*.tfvars.example"
echo "  ✅ Terraform files updated"
echo ""

# 4. Replace in scripts
echo "🔧 Step 4: Updating scripts..."
replace_in_files "acme-llc" "$CUSTOMER_A_NAME" "*.sh"
replace_in_files "globex" "$CUSTOMER_B_NAME" "*.sh"
replace_in_files "proj-acme-llc-prod" "$CUSTOMER_A_PROJECT" "*.sh"
replace_in_files "proj-globex-prod" "$CUSTOMER_B_PROJECT" "*.sh"
echo "  ✅ Scripts updated"
echo ""

# 5. Replace in GitHub workflows
echo "⚙️  Step 5: Updating GitHub workflows..."
replace_in_files "acme-llc" "$CUSTOMER_A_NAME" "*.yml"
replace_in_files "globex" "$CUSTOMER_B_NAME" "*.yml"
replace_in_files "proj-acme-llc-prod" "$CUSTOMER_A_PROJECT" "*.yml"
replace_in_files "proj-globex-prod" "$CUSTOMER_B_PROJECT" "*.yml"
echo "  ✅ GitHub workflows updated"
echo ""

# 6. Replace in other config files
echo "📝 Step 6: Updating configuration files..."
replace_in_files "acme-llc" "$CUSTOMER_A_NAME" "*.yaml"
replace_in_files "globex" "$CUSTOMER_B_NAME" "*.yaml"
replace_in_files "acme-llc" "$CUSTOMER_A_NAME" "*.example"
replace_in_files "globex" "$CUSTOMER_B_NAME" "*.example"
replace_in_files "proj-acme-llc-prod" "$CUSTOMER_A_PROJECT" "*.example"
replace_in_files "proj-globex-prod" "$CUSTOMER_B_PROJECT" "*.example"
echo "  ✅ Configuration files updated"
echo ""

echo "=================================================="
echo "✅ Customer setup completed successfully!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Update your platform Terraform:"
echo "     cd infra/envs/platform"
echo "     cp terraform.tfvars.example terraform.tfvars"
echo "     # Edit terraform.tfvars with your values"
echo "     terraform init && terraform apply"
echo ""
echo "  3. Set up GitHub secrets (see docs/SECRETS_SETUP.md)"
echo "  4. Deploy to staging: git push origin staging"
echo "  5. Deploy to customers with tags:"
echo "     git tag deploy-prod-$CUSTOMER_A_NAME-v1.0.0"
echo "     git tag deploy-prod-$CUSTOMER_B_NAME-v1.0.0"
echo ""
echo "📚 For detailed instructions, see docs/QUICK_START.md"
echo ""

