output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for ECS tasks"
  value       = module.ecs.log_group_name
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${module.alb.alb_dns_name}"
}

# Deployment Information
output "deployment_info" {
  description = "Deployment information and next steps"
  value       = <<-EOT

    Deployment Complete!

    Application URL: http://${module.alb.alb_dns_name}
    ECR Repository: ${module.ecr.repository_url}
    ECS Cluster: ${module.ecs.cluster_name}
    CloudWatch Logs: ${module.ecs.log_group_name}

    Next Steps:
    1. Build and push your Docker image to ECR:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.repository_url}
       docker build -t ${module.ecr.repository_url}:${var.container_image_tag} .
       docker push ${module.ecr.repository_url}:${var.container_image_tag}

    2. Update the ECS service to deploy the new image:
       aws ecs update-service --cluster ${module.ecs.cluster_name} --service ${module.ecs.service_name} --force-new-deployment --region ${var.aws_region}

    3. Monitor deployment:
       aws ecs describe-services --cluster ${module.ecs.cluster_name} --services ${module.ecs.service_name} --region ${var.aws_region}

  EOT
}
