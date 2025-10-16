#!/bin/bash

# Script to parse deployment tags and extract customer-id and version
# Usage: ./parse-tag.sh <tag>
# Example: ./parse-tag.sh deploy-prod-acme-llc-v1.0.0

set -e

TAG="$1"

if [ -z "$TAG" ]; then
    echo "Usage: $0 <tag>"
    echo "Example: $0 deploy-prod-acme-llc-v1.0.0"
    exit 1
fi

# Validate tag format: deploy-prod-<customer-id>-<version>
if [[ $TAG =~ ^deploy-prod-([a-z0-9-]+)-(.+)$ ]]; then
    CUSTOMER_ID="${BASH_REMATCH[1]}"
    VERSION="${BASH_REMATCH[2]}"
    PROJECT_ID="proj-$CUSTOMER_ID-prod"
    
    echo "Customer ID: $CUSTOMER_ID"
    echo "Version: $VERSION"
    echo "Project ID: $PROJECT_ID"
    
    # Export variables for use in other scripts
    export CUSTOMER_ID
    export VERSION
    export PROJECT_ID
    
    # Create a temporary file with the parsed values
    cat > /tmp/deployment-info.env << EOF
CUSTOMER_ID=$CUSTOMER_ID
VERSION=$VERSION
PROJECT_ID=$PROJECT_ID
EOF
    
    echo "Deployment info saved to /tmp/deployment-info.env"
else
    echo "❌ Invalid tag format: $TAG"
    echo "Expected format: deploy-prod-<customer-id>-<version>"
    echo "Example: deploy-prod-acme-llc-v1.0.0"
    exit 1
fi
