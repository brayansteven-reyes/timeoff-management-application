output "task_arn" {
  description = "The full Amazon Resource Name (ARN) of the task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "service_arn" {
  description = "The full Amazon Resource Name (ARN) of the ECS service"
  value       = aws_ecs_service.this.id
}

output "target_group_arn" {
  description = "The full Amazon Resource Name (ARN) of the target group"
  value       = aws_lb_target_group.this.arn
}
