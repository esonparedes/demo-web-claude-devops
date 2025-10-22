#!/bin/bash

# deploy.sh - Build Docker image and push to ECR, then update ECS service
# Usage: ./deploy.sh [environment] [aws-region]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"
PROJECT_NAME="demo-web"

echo -e "${YELLOW}=== Docker Build and ECR Push Script ===${NC}"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "AWS Region: $AWS_REGION"
echo ""

# Verify Dockerfile exists
if [ ! -f "../Dockerfile" ]; then
    echo -e "${RED}Error: Dockerfile not found at ../Dockerfile${NC}"
    exit 1
fi

# Verify terraform variables file
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and update values"
    exit 1
fi

# Get AWS account ID
echo -e "${YELLOW}Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Could not retrieve AWS Account ID. Check your AWS credentials.${NC}"
    exit 1
fi
echo -e "${GREEN}Account ID: $AWS_ACCOUNT_ID${NC}"

# ECR repository name
ECR_REPO="${PROJECT_NAME}-${ENVIRONMENT}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

# Check if ECR repository exists
echo ""
echo -e "${YELLOW}Checking ECR repository...${NC}"
if ! aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${YELLOW}ECR repository does not exist. Creating...${NC}"
    aws ecr create-repository \
        --repository-name "$ECR_REPO" \
        --region "$AWS_REGION" \
        --image-scanning-configuration scanOnPush=true
    echo -e "${GREEN}ECR repository created${NC}"
else
    echo -e "${GREEN}ECR repository exists${NC}"
fi

# Login to ECR
echo ""
echo -e "${YELLOW}Logging in to ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URI"
echo -e "${GREEN}ECR login successful${NC}"

# Build Docker image
echo ""
echo -e "${YELLOW}Building Docker image...${NC}"
IMAGE_TAG="latest"
TIMESTAMP=$(date +%s)
TIMESTAMP_TAG="$TIMESTAMP"
docker build -t "$ECR_URI:$IMAGE_TAG" -t "$ECR_URI:$TIMESTAMP_TAG" ../
echo -e "${GREEN}Docker image built successfully${NC}"

# Push to ECR
echo ""
echo -e "${YELLOW}Pushing image to ECR...${NC}"
docker push "$ECR_URI:$IMAGE_TAG"
docker push "$ECR_URI:$TIMESTAMP_TAG"
echo -e "${GREEN}Image pushed to ECR successfully${NC}"

# Get the image digest
IMAGE_DIGEST=$(docker inspect --format='{{.RepoDigests}}' "$ECR_URI:$IMAGE_TAG" | sed 's/.*\(@sha256:[^ ]*\).*/\1/')

echo ""
echo -e "${GREEN}=== Deployment Summary ===${NC}"
echo "ECR Repository: $ECR_REPO"
echo "ECR URI: $ECR_URI"
echo "Image Tag: $IMAGE_TAG"
echo "Image Digest: $IMAGE_DIGEST"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update Terraform to deploy the new image:"
echo "   cd terraform"
echo "   terraform apply"
echo ""
echo "   Or set the image URI directly:"
echo "   terraform apply -var='container_image=$ECR_URI:$IMAGE_TAG'"
echo ""
echo -e "${GREEN}Deployment script completed successfully!${NC}"
