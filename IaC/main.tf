locals {
  service_name = "timeoff"
  common_tags = {
    Environment = local.env_name
    Owner       = "DevOps"
    ManagedBy   = "Terraform"
  }
  env_name        = "dev"
  container_image = ":latest"
}


module "timeoff_cluster" {
  source                   = "./modules/ecs-cluster"
  cluster_name             = local.service_name
  env_name                 = "dev"
  common_tags              = local.common_tags
  target_capacity_provider = 100
  vpc_id                   = aws_default_vpc.default.id
}

module "timeoff_portal" {
  source          = "./modules/ecs-service"
  env_name        = local.env_name
  common_tags     = local.common_tags
  service_cluster = format("%s-%s",local.service_name,local.env_name)
  vpc_id          = aws_default_vpc.default.id
  container_image = local.container_image
  service_name    = local.service_name
  listener_arn    = aws_lb_listener.listener.arn
  https_listener_rules = [
    {
      conditions = [{
        path_patterns = ["/*"]
      }]
    }
  ]
  portMappings = [
    {
      containerPort = 443
      protocol      = "tcp"
    },
    {
      containerPort = 80
      protocol      = "tcp"
    }
  ]
}

resource "aws_lb" "load_balancer" {
  name                       = local.service_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [module.timeoff_cluster.cluster_security_group_id]
  subnets                    = data.aws_subnets.default.ids
  enable_deletion_protection = false
  tags = merge(local.common_tags, {
    "Name" = local.service_name
  })
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_lb.load_balancer.dns_name
    origin_id   = local.service_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Distribution for ALB"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.service_name
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_elasticache_subnet_group" "elasticache_subnets" {
  name       = local.service_name
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_elasticache_replication_group" "cnv_portal_api_cache" {
  engine                     = "redis"
  engine_version             = "6.x"
  num_cache_clusters         = 1
  replicas_per_node_group    = 0
  replication_group_id       = local.service_name
  description                = "Redis cluster"
  node_type                  = "cache.t4g.micro"
  port                       = 6379
  snapshot_retention_limit   = 7
  snapshot_window            = "00:00-03:00"
  automatic_failover_enabled = false
  auto_minor_version_upgrade = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  subnet_group_name          = aws_elasticache_subnet_group.elasticache_subnets.id
}
