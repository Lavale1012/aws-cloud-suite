# Inputs from the root module. VPC/subnet IDs come from networking outputs.

variable "vpc_id" {
  description = "var for vpc id"
  type = string
}

# Private subnets - where ECS tasks run (2 AZs for HA)
variable "private_subnet_id_1" {
  description = "ID of the first private subnet"
  type = string

}

variable "private_subnet_id_2" {
  description = "ID of the second private subnet"
  type = string

}

# Public subnets - where the ALB sits to receive internet traffic
variable "public_subnet_id" {
  description = "ID of the public subnet"
  type = string

}
variable "public_subnet_id_2" {
  description = "ID of the second public subnet"
  type = string

}

variable "project_name" {
  description = "Name of the project"
  type = string
}
