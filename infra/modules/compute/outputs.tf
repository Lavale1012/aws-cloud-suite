
output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs_security_group.id
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.cloud_suite_ecs_cluster.name
  description = "Name of ecs cluster"
}

output "ecs_service_name" {
  value       = aws_ecs_service.cloud_suite_ecs_service.name
  description = "Name of ecs service"
}

output "alb_arn_suffix" {
  value       = aws_lb.cloud_suite_lb.arn_suffix
  description = "Application load balancer arn suffix"
}
