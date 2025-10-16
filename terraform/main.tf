terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Application = "demo-web-claude-devops"
    }
  }
}

# VPC Module - Creates network infrastructure with multi-AZ support
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ECR Module - Creates container registry for Docker images
module "ecr" {
  source = "./modules/ecr"

  project_name         = var.project_name
  environment          = var.environment
  image_tag_mutability = var.ecr_image_tag_mutability
  scan_on_push         = var.ecr_scan_on_push
}

# Security Groups Module - Defines network access rules
module "security_groups" {
  source = "./modules/security-groups"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  alb_ingress_cidr_blocks = var.alb_ingress_cidr_blocks
}

# IAM Module - Creates roles and policies for ECS tasks
module "iam" {
  source = "./modules/iam"

  project_name       = var.project_name
  environment        = var.environment
  ecr_repository_arn = module.ecr.repository_arn
}

# ALB Module - Creates Application Load Balancer
module "alb" {
  source = "./modules/alb"

  project_name                     = var.project_name
  environment                      = var.environment
  vpc_id                           = module.vpc.vpc_id
  public_subnet_ids                = module.vpc.public_subnet_ids
  alb_security_group_id            = module.security_groups.alb_security_group_id
  health_check_path                = var.health_check_path
  health_check_interval            = var.health_check_interval
  health_check_timeout             = var.health_check_timeout
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
}

# ECS Module - Creates cluster, task definition, and service
module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id

  # ECR
  ecr_repository_url  = module.ecr.repository_url
  container_image_tag = var.container_image_tag

  # Task Configuration
  task_cpu       = var.task_cpu
  task_memory    = var.task_memory
  container_port = var.container_port

  # IAM
  task_execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn           = module.iam.task_role_arn

  # Service Configuration
  desired_count = var.desired_count
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity

  # ALB Integration
  target_group_arn = module.alb.target_group_arn

  # CloudWatch
  enable_container_insights = var.enable_container_insights
}
