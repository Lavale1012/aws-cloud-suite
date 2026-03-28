# Top-level inputs for the infrastructure. Override in terraform.tfvars or via -var flag.

variable "aws_region" {
  type = string
  default = "us-east-1"
  description = "The is the region of the provider"
}

# /16 = 65,536 IPs, subdivided into /24 subnets (256 IPs each) in the networking module
variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
  description = "This is the vpc cidr range"
}

# Used as a prefix for naming all resources (e.g., "cloud-suite-cluster")
variable "project_name" {
  type = string
  default = "cloud-suite"
  description = "The name of the project"
}
