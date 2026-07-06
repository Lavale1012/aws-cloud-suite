# Inputs from the root module. VPC/subnet IDs come from networking outputs.

variable "vpc_id" {
  description = "var for vpc id"
  type        = string
}

# Private subnets - where ECS tasks run (2 AZs for HA)
variable "private_subnet_id_1" {
  description = "ID of the first private subnet"
  type        = string

}

variable "private_subnet_id_2" {
  description = "ID of the second private subnet"
  type        = string

}

# Public subnets - where the ALB sits to receive internet traffic
variable "public_subnet_id" {
  description = "ID of the public subnet"
  type        = string

}
variable "public_subnet_id_2" {
  description = "ID of the second public subnet"
  type        = string

}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "jwt_secret" {
  type        = string
  sensitive   = true
  description = "JWT secret for Nimbus API"
}

variable "redis_addr" {
  type        = string
  default     = ""
  description = "Redis endpoint (host:port) for the rate limiter. Empty falls back to in-memory limiting."
}

variable "db_username" {
  type        = string
  sensitive   = true
  description = "Database username for Nimbus API"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database password for Nimbus API"
}
