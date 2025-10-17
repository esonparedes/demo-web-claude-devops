variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (minimum t3.medium for 2 vCPUs, 4GB RAM)"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name for EC2 instance access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_web_cidr" {
  description = "CIDR blocks allowed to access SonarQube web interface"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "sonarqube_db_password" {
  description = "PostgreSQL password for SonarQube database"
  type        = string
  sensitive   = true
  default     = "StrongPasswordHere123!"
}
