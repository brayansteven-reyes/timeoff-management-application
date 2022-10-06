locals {
  cluster_name = format("%s-%s", var.cluster_name, var.env_name)
}

resource "aws_security_group" "this" {
  name        = format("sg%s", lower(local.cluster_name))
  description = format("Security Group for cluster sg-%s", lower(local.cluster_name))
  vpc_id      = data.aws_vpc.this.id
  tags        = var.common_tags

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat([data.aws_vpc.this.cidr_block], var.security_group_additional_cidr_blocks)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name = format("%s-instance-role", lower(local.cluster_name))
  path = "/"
  tags = var.common_tags

  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  inline_policy {
    name   = "ecs_register_instance"
    policy = data.aws_iam_policy_document.read_secrets_manager.json
  }
  inline_policy {
    name   = "read_secrets_manager"
    policy = data.aws_iam_policy_document.read_secrets_manager.json
  }
}

resource "aws_iam_instance_profile" "ecs_service_role" {
  role = aws_iam_role.ecs_instance_role.name
  tags = var.common_tags
}

resource "aws_launch_template" "this" {
  name                                 = local.cluster_name
  disable_api_termination              = true
  update_default_version               = true
  image_id                             = data.aws_ami.amazon_linux.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  vpc_security_group_ids               = [aws_security_group.this.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 30
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_service_role.name
  }

  user_data = base64encode("#!/bin/bash \n echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config")

}

resource "aws_autoscaling_group" "this" {
  name                      = format("asg-%s", local.cluster_name)
  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 10
  health_check_type         = "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = data.aws_subnets.private.ids
  force_delete              = true
  termination_policies      = ["OldestInstance"]
  protect_from_scale_in     = var.env_name == "prod" ? true : false
  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name
  tags = var.common_tags
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = format("capacity-provider-%s", local.cluster_name)
  tags = var.common_tags

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = var.env_name == "prod" ? "ENABLED" : "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 5
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = var.target_capacity_provider
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 1
    capacity_provider = aws_ecs_capacity_provider.this.name
  }
}
