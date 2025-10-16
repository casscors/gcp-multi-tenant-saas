#!/bin/bash

# Terraform wrapper script that sets backend and providers dynamically
# Usage: ./tf-wrapper.sh <environment> <command>
# Example: ./tf-wrapper.sh staging plan
# Example: ./tf-wrapper.sh customers/acme-llc apply

set -e

ENVIRONMENT="$1"
COMMAND="$2"

if [ -z "$ENVIRONMENT" ] || [ -z "$COMMAND" ]; then
    echo "Usage: $0 <environment> <command>"
    echo "Examples:"
    echo "  $0 staging plan"
    echo "  $0 customers/acme-llc apply"
    echo "  $0 platform init"
    exit 1
fi

# Set working directory
TF_DIR="infra/envs/$ENVIRONMENT"

if [ ! -d "$TF_DIR" ]; then
    echo "❌ Environment directory not found: $TF_DIR"
    exit 1
fi

echo "🔧 Running Terraform $COMMAND in $TF_DIR"

# Change to the terraform directory
cd "$TF_DIR"

# Run terraform command
case "$COMMAND" in
    "init")
        echo "Initializing Terraform..."
        terraform init
        ;;
    "plan")
        echo "Planning Terraform changes..."
        terraform plan
        ;;
    "apply")
        echo "Applying Terraform changes..."
        terraform apply -auto-approve
        ;;
    "destroy")
        echo "Destroying Terraform resources..."
        terraform destroy -auto-approve
        ;;
    "output")
        echo "Showing Terraform outputs..."
        terraform output
        ;;
    "validate")
        echo "Validating Terraform configuration..."
        terraform validate
        ;;
    "fmt")
        echo "Formatting Terraform files..."
        terraform fmt -recursive
        ;;
    *)
        echo "Running custom Terraform command: $COMMAND"
        terraform $COMMAND
        ;;
esac

echo "✅ Terraform $COMMAND completed successfully"
