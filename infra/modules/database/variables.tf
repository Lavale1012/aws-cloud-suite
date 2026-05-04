variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_1" {
  type        = string
  description = "Private Subnet 1 ID"
}

variable "private_subnet_2" {
  type        = string
  description = "Private Subnet 2 ID"
}

variable "project_name" {
  type        = string
  description = "Project Name"
}

variable "ecs_security_group" {
  type        = string
  description = "ecs security group ID"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
