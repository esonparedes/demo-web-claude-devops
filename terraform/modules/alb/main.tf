# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # Enable deletion protection in production
  enable_deletion_protection = var.environment == "prod" ? true : false

  # Enable access logs (requires S3 bucket, commented out for initial deployment)
  # access_logs {
  #   bucket  = aws_s3_bucket.alb_logs.id
  #   prefix  = "alb-logs"
  #   enabled = true
  # }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group for ECS Service
resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  # Deregistration delay for graceful shutdowns
  deregistration_delay = 30

  # Stickiness configuration (session affinity)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 1 day
    enabled         = false # Disabled by default, enable if needed
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  # Uncomment to redirect HTTP to HTTPS when SSL certificate is configured
  # default_action {
  #   type = "redirect"
  #
  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }

  tags = {
    Name = "${var.project_name}-${var.environment}-http-listener"
  }
}

# HTTPS Listener (uncomment when SSL certificate is available)
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = var.certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.main.arn
#   }
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-https-listener"
#   }
# }

# Optional: S3 bucket for ALB access logs
# Uncomment when access logging is required
# resource "aws_s3_bucket" "alb_logs" {
#   bucket = "${var.project_name}-${var.environment}-alb-logs"
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-alb-logs"
#   }
# }
#
# resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
#   bucket = aws_s3_bucket.alb_logs.id
#
#   rule {
#     id     = "expire-old-logs"
#     status = "Enabled"
#
#     expiration {
#       days = 90
#     }
#   }
# }
#
# resource "aws_s3_bucket_public_access_block" "alb_logs" {
#   bucket = aws_s3_bucket.alb_logs.id
#
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }
#
# resource "aws_s3_bucket_policy" "alb_logs" {
#   bucket = aws_s3_bucket.alb_logs.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::127311923021:root" # ELB service account for us-east-1
#         }
#         Action   = "s3:PutObject"
#         Resource = "${aws_s3_bucket.alb_logs.arn}/*"
#       }
#     ]
#   })
# }
