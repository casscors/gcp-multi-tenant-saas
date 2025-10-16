#!/bin/bash

# Script to initialize Git repository and set up branches
# Run this from the repository root

set -e

echo "🚀 Initializing Git repository..."
echo ""

# Check if already a git repo
if [ -d ".git" ]; then
    echo "⚠️  Git repository already exists."
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    # Initialize git repo
    git init
    echo "✅ Initialized empty Git repository"
fi

# Create .gitkeep files for empty directories that should be tracked
echo "📁 Creating .gitkeep files for empty directories..."
touch app/.gitkeep 2>/dev/null || true
touch docs/.gitkeep 2>/dev/null || true

# Initial commit
echo "📝 Creating initial commit..."
git add .
git commit -m "Initial commit: Multi-tenant GCP infrastructure

- Complete Terraform infrastructure for platform, staging, and customers
- Customer-stamp reusable module for tenant isolation
- GitHub Actions workflows for staging and production deployments
- Kubernetes manifests for local development
- Application skeleton with Express.js
- Documentation for secrets setup and deployment

Customers initialized:
- acme-llc: Multi-website deployment
- globex: Hybrid cloud, multi-cluster setup" || echo "No changes to commit"

# Create staging branch
echo "🌿 Creating staging branch..."
git checkout -b staging 2>/dev/null || git checkout staging
git checkout main 2>/dev/null || git checkout -b main

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Git repository initialized!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Branches created:"
echo "  • main    - Production releases"
echo "  • staging - Staging deployments (triggers staging workflow)"
echo ""
echo "Next steps:"
echo ""
echo "1. Add remote repository:"
echo "   git remote add origin https://github.com/YOUR_ORG/YOUR_REPO.git"
echo ""
echo "2. Push branches:"
echo "   git push -u origin main"
echo "   git push -u origin staging"
echo ""
echo "3. Set up branch protection (recommended):"
echo "   • Go to GitHub → Settings → Branches"
echo "   • Protect 'main' branch: require pull request reviews"
echo "   • Protect 'staging' branch: require status checks"
echo ""
echo "4. Deploy to staging:"
echo "   git checkout staging"
echo "   git merge main"
echo "   git push origin staging"
echo "   # This triggers .github/workflows/staging.yml"
echo ""
echo "5. Deploy to production (customers):"
echo "   git tag deploy-prod-acme-llc-v1.0.0"
echo "   git push origin deploy-prod-acme-llc-v1.0.0"
echo "   # This triggers .github/workflows/prod-tag.yml"
echo ""
