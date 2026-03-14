variable "aws_region" {
  type = string
  default = "us-east-1"
  description = "The is the region of the provider"
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
  description = "This is the vpc cidr range"
}

variable "project_name" {
  type = string
  default = "cloud-suite"
  description = "The name of the project"
}