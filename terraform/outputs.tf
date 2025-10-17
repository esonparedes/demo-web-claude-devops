# ECR Repository Output
output "ecr_repository_url" {
  description = "URL of the ECR repository for Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app.arn
}

# Load Balancer Output
output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer (use this to access your application)"
  value       = aws_lb.app.dns_name
}

output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.app.arn
}

output "load_balancer_url" {
  description = "Full URL to access the application (add http:// prefix)"
  value       = "http://${aws_lb.app.dns_name}"
}

# ECS Service Output
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.app.arn
}

# Deployment Instructions
output "deployment_info" {
  description = "Information needed to deploy the application"
  value = {
    repository_url = aws_ecr_repository.app.repository_url
    cluster_name   = aws_ecs_cluster.app.name
    service_name   = aws_ecs_service.app.name
    alb_dns_name   = aws_lb.app.dns_name
    app_url        = "http://${aws_lb.app.dns_name}"
  }
}
