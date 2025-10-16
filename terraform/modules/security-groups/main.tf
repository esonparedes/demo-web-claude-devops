# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Ingress Rules - HTTP
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP traffic from specified CIDR blocks"

  cidr_ipv4   = var.alb_ingress_cidr_blocks[0]
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-http-ingress"
  }
}

# ALB Ingress Rules - HTTPS (commented out, enable when SSL certificate is configured)
# resource "aws_vpc_security_group_ingress_rule" "alb_https" {
#   security_group_id = aws_security_group.alb.id
#   description       = "Allow HTTPS traffic from specified CIDR blocks"
#
#   cidr_ipv4   = var.alb_ingress_cidr_blocks[0]
#   from_port   = 443
#   to_port     = 443
#   ip_protocol = "tcp"
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-alb-https-ingress"
#   }
# }

# ALB Egress Rules - Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-egress"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Ingress Rules - Allow traffic from ALB only
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow traffic from ALB to ECS tasks"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-from-alb"
  }
}

# ECS Egress Rules - Allow all outbound traffic (for pulling images, accessing AWS services)
resource "aws_vpc_security_group_egress_rule" "ecs_egress" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow all outbound traffic from ECS tasks"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-egress"
  }
}
