# Backend configuration for Terraform state management
#
# IMPORTANT: Before using this backend, you must:
# 1. Create an S3 bucket for state storage
# 2. Create a DynamoDB table for state locking
# 3. Update the bucket, key, and region values below
#
# To create the required resources:
#
# aws s3api create-bucket \
#   --bucket your-terraform-state-bucket \
#   --region us-east-1
#
# aws s3api put-bucket-versioning \
#   --bucket your-terraform-state-bucket \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket your-terraform-state-bucket \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1
#
# Uncomment and configure the backend below after creating the resources:

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "demo-web-app/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# For development/testing, you can use local backend (default)
# State will be stored in terraform.tfstate file locally
# WARNING: Local backend is not recommended for production use
