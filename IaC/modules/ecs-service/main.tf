locals {
  service_name = format("%s-%s", var.service_name, var.env_name)
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.service_name
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  memory                   = var.container_memory
  cpu                      = var.container_cpu
  execution_role_arn       = data.aws_iam_role.ecsTaskExecutionRole.arn 
  task_role_arn            = data.aws_iam_role.ecsTaskExecutionRole.arn 
  container_definitions = jsonencode([
    {
      name      = local.service_name
      image     = var.container_image
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true
      logConfiguration = {
        logDriver     = "gelf",
        secretOptions = null,
      }
      portMappings = var.portMappings
      environment = [{
        "name" : "LAST_DEPLOY_TIME",
        "value" : timestamp()
        }
      ]
    }
  ])
  tags = merge(var.common_tags, {
    "name" = local.service_name
  })
}

resource "aws_lb_target_group" "this" {
  name                 = format("%s-%s",length(local.service_name)<29 ? local.service_name : substr(local.service_name,3,32) ,substr(uuid(), 0, 3))
  protocol             = "HTTPS"
  vpc_id               = var.vpc_id
  port                 = 443
  deregistration_delay = 30

  health_check {
    path                = var.path_healthcheck
    protocol            = "HTTPS"
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    "name" = local.service_name
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }
}

resource "aws_ecs_service" "this" {
  name                              = local.service_name
  cluster                           = var.service_cluster
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.service_desired_count
  force_new_deployment              = true
  health_check_grace_period_seconds = 0
  wait_for_steady_state             = true

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = local.service_name
    container_port   = var.portMappings[0].containerPort
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = merge(var.common_tags, {
    "name" = local.service_name
  })
}

resource "aws_lb_listener_rule" "host_based_weighted_routing" {
  count        = 1
  listener_arn = var.listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "host_headers", [])) > 0
    ]

    content {
      host_header {
        values = condition.value["host_headers"]
      }
    }
  }

  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "path_patterns", [])) > 0
    ]

    content {
      path_pattern {
        values = condition.value["path_patterns"]
      }
    }
  }

}
