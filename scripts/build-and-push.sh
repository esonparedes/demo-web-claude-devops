#!/bin/bash

# Build and Push Docker Image to ECR
# Usage: ./scripts/build-and-push.sh <environment> [image-tag]
#
# Example:
#   ./scripts/build-and-push.sh dev latest
#   ./scripts/build-and-push.sh prod v1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if environment is provided
if [ -z "$1" ]; then
    print_error "Environment not specified"
    echo "Usage: $0 <environment> [image-tag]"
    echo "Example: $0 dev latest"
    exit 1
fi

ENVIRONMENT=$1
IMAGE_TAG=${2:-latest}

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_info "Project root: $PROJECT_ROOT"
print_info "Environment: $ENVIRONMENT"
print_info "Image tag: $IMAGE_TAG"

# Change to project root
cd "$PROJECT_ROOT"

# Get AWS region from Terraform output or use default
AWS_REGION=${AWS_REGION:-us-east-1}

# Get ECR repository URL from Terraform output
print_info "Getting ECR repository URL from Terraform..."
cd terraform

ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")

if [ -z "$ECR_REPO_URL" ]; then
    print_error "Could not get ECR repository URL from Terraform output"
    print_error "Make sure you have run 'terraform apply' first"
    exit 1
fi

print_info "ECR Repository URL: $ECR_REPO_URL"

# Return to project root
cd "$PROJECT_ROOT"

# Login to ECR
print_info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REPO_URL"

if [ $? -ne 0 ]; then
    print_error "Failed to login to ECR"
    exit 1
fi

print_info "Successfully logged in to ECR"

# Build Docker image
print_info "Building Docker image..."
docker build -t demo-web-claude-devops:"$IMAGE_TAG" .

if [ $? -ne 0 ]; then
    print_error "Failed to build Docker image"
    exit 1
fi

print_info "Successfully built Docker image"

# Tag image for ECR
print_info "Tagging image for ECR..."
docker tag demo-web-claude-devops:"$IMAGE_TAG" "$ECR_REPO_URL":"$IMAGE_TAG"

# Push image to ECR
print_info "Pushing image to ECR..."
docker push "$ECR_REPO_URL":"$IMAGE_TAG"

if [ $? -ne 0 ]; then
    print_error "Failed to push image to ECR"
    exit 1
fi

print_info "Successfully pushed image to ECR"
print_info "Image: $ECR_REPO_URL:$IMAGE_TAG"

# Optional: Update ECS service to use new image
read -p "Do you want to update the ECS service to use this new image? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$PROJECT_ROOT/terraform"

    ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    ECS_SERVICE=$(terraform output -raw ecs_service_name 2>/dev/null || echo "")

    if [ -z "$ECS_CLUSTER" ] || [ -z "$ECS_SERVICE" ]; then
        print_error "Could not get ECS cluster or service name from Terraform output"
        exit 1
    fi

    print_info "Updating ECS service..."
    print_info "Cluster: $ECS_CLUSTER"
    print_info "Service: $ECS_SERVICE"

    aws ecs update-service \
        --cluster "$ECS_CLUSTER" \
        --service "$ECS_SERVICE" \
        --force-new-deployment \
        --region "$AWS_REGION"

    if [ $? -eq 0 ]; then
        print_info "ECS service update initiated successfully"
        print_info "Monitor deployment with: aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION"
    else
        print_error "Failed to update ECS service"
        exit 1
    fi
fi

print_info "Done!"
