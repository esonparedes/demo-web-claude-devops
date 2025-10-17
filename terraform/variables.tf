variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "demo-web"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens only."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "app_port" {
  description = "Port on which the Express.js application listens"
  type        = number
  default     = 3000
  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "Port must be between 1 and 65535."
  }
}

variable "container_cpu" {
  description = "CPU units for the Fargate task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.container_cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "container_memory" {
  description = "Memory (MB) for the Fargate task (512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192)"
  type        = number
  default     = 512
  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192], var.container_memory)
    error_message = "Memory must be a valid Fargate memory value."
  }
}

variable "desired_count" {
  description = "Desired number of ECS tasks to run"
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count > 0 && var.desired_count <= 10
    error_message = "Desired count must be between 1 and 10."
  }
}

variable "container_image" {
  description = "Docker image URI for the Express.js application (will be set by deploy script)"
  type        = string
  default     = ""
}

variable "enable_logging" {
  description = "Enable CloudWatch logging for ECS tasks"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 7
  validation {
    condition     = var.log_retention_days > 0 && var.log_retention_days <= 3653
    error_message = "Log retention must be between 1 and 3653 days."
  }
}
