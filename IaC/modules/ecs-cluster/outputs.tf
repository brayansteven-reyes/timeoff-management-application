output "cluster_security_group" {
  value = aws_security_group.this.arn
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cluster_instance_role_arn" {
  value = aws_iam_role.ecs_instance_role.arn
}

output "cluster_security_group_id" {
  value = aws_security_group.this.id
}