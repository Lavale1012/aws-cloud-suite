# Inputs passed from the root module (infra/main.tf)

variable "vpc_cidr" {
  type = string
  description = "This is the vpc cidr range"
}

variable "project_name" {
  type = string
  description = "The name of the project"
}
