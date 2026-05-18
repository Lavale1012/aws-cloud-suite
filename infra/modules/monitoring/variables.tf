variable "ecs_cluster_name" {
  type        = string
  description = "The name of the ECS cluster"
}

variable "ecs_service_name" {
  type        = string
  description = "The name for the ECS service"
}

variable "db_instance_identifier" {
  type        = string
  description = "DB instance identifier"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix"
}
variable "project_name" {
  type        = string
  description = "The name of the project"
}
variable "notification_email" {
  type        = string
  description = "Email for SNS"
}
