#!/bin/bash

# Complete Deployment Script
# This script handles the entire deployment process:
# 1. Validates environment
# 2. Runs Terraform plan
# 3. Applies Terraform changes (with confirmation)
# 4. Builds and pushes Docker image
# 5. Updates ECS service
#
# Usage: ./scripts/deploy.sh <environment> [image-tag]
#
# Example:
#   ./scripts/deploy.sh dev latest
#   ./scripts/deploy.sh prod v1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if environment is provided
if [ -z "$1" ]; then
    print_error "Environment not specified"
    echo "Usage: $0 <environment> [image-tag]"
    echo "Example: $0 dev latest"
    exit 1
fi

ENVIRONMENT=$1
IMAGE_TAG=${2:-latest}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_error "Valid environments: dev, staging, prod"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_info "=========================================="
print_info "Deployment Configuration"
print_info "=========================================="
print_info "Project root: $PROJECT_ROOT"
print_info "Environment: $ENVIRONMENT"
print_info "Image tag: $IMAGE_TAG"
print_info "=========================================="
echo ""

# Get AWS region
AWS_REGION=${AWS_REGION:-us-east-1}

# Change to Terraform directory
cd "$PROJECT_ROOT/terraform"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    print_warning "Terraform not initialized"
    print_step "Initializing Terraform..."
    terraform init
fi

# STEP 1: Terraform Plan
print_step "Step 1/5: Running Terraform plan..."
TFVARS_FILE="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT/$ENVIRONMENT.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
    print_error "tfvars file not found: $TFVARS_FILE"
    exit 1
fi

terraform plan -var-file="$TFVARS_FILE" -out=tfplan

if [ $? -ne 0 ]; then
    print_error "Terraform plan failed"
    exit 1
fi

print_info "Terraform plan completed successfully"
echo ""

# STEP 2: Terraform Apply
print_step "Step 2/5: Applying Terraform changes..."
read -p "Do you want to apply these changes? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deployment cancelled by user"
    rm -f tfplan
    exit 0
fi

terraform apply tfplan

if [ $? -ne 0 ]; then
    print_error "Terraform apply failed"
    rm -f tfplan
    exit 1
fi

rm -f tfplan
print_info "Terraform apply completed successfully"
echo ""

# Get ECR repository URL from Terraform output
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform output -raw ecs_service_name)

print_info "Infrastructure deployed:"
print_info "  ECR Repository: $ECR_REPO_URL"
print_info "  ECS Cluster: $ECS_CLUSTER"
print_info "  ECS Service: $ECS_SERVICE"
echo ""

# STEP 3: Build Docker Image
print_step "Step 3/5: Building Docker image..."
cd "$PROJECT_ROOT"

docker build -t demo-web-claude-devops:"$IMAGE_TAG" .

if [ $? -ne 0 ]; then
    print_error "Failed to build Docker image"
    exit 1
fi

print_info "Docker image built successfully"
echo ""

# STEP 4: Push to ECR
print_step "Step 4/5: Pushing image to ECR..."

# Login to ECR
print_info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REPO_URL"

if [ $? -ne 0 ]; then
    print_error "Failed to login to ECR"
    exit 1
fi

# Tag and push image
docker tag demo-web-claude-devops:"$IMAGE_TAG" "$ECR_REPO_URL":"$IMAGE_TAG"
docker push "$ECR_REPO_URL":"$IMAGE_TAG"

if [ $? -ne 0 ]; then
    print_error "Failed to push image to ECR"
    exit 1
fi

print_info "Image pushed to ECR successfully"
echo ""

# STEP 5: Update ECS Service
print_step "Step 5/5: Updating ECS service..."

aws ecs update-service \
    --cluster "$ECS_CLUSTER" \
    --service "$ECS_SERVICE" \
    --force-new-deployment \
    --region "$AWS_REGION" \
    --no-cli-pager

if [ $? -ne 0 ]; then
    print_error "Failed to update ECS service"
    exit 1
fi

print_info "ECS service update initiated"
echo ""

# Get ALB DNS name
cd "$PROJECT_ROOT/terraform"
ALB_DNS=$(terraform output -raw alb_dns_name)

print_info "=========================================="
print_info "Deployment Summary"
print_info "=========================================="
print_info "Environment: $ENVIRONMENT"
print_info "Image: $ECR_REPO_URL:$IMAGE_TAG"
print_info "ECS Cluster: $ECS_CLUSTER"
print_info "ECS Service: $ECS_SERVICE"
print_info "Application URL: http://$ALB_DNS"
print_info ""
print_info "Monitor deployment:"
print_info "  aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION"
print_info ""
print_info "View logs:"
print_info "  aws logs tail /ecs/demo-web-app-$ENVIRONMENT --follow --region $AWS_REGION"
print_info ""
print_warning "Note: It may take 2-3 minutes for the service to become healthy"
print_info "=========================================="
print_info "Deployment completed successfully!"
print_info "=========================================="
