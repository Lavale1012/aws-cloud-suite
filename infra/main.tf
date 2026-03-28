# Root module - configures AWS provider and calls networking + compute modules.
# Flow: networking creates VPC/subnets -> outputs feed into compute module.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Creates VPC, subnets, IGW, NAT gateway, and route tables
module "networking" {
  source = "./modules/networking"
  vpc_cidr = var.vpc_cidr
  project_name = var.project_name

}

# Creates ECS Fargate cluster, ALB, ECR, IAM, security groups, and CloudWatch logs.
# Depends on networking outputs for VPC/subnet IDs.
module "compute" {
  source              = "./modules/compute"
  vpc_id              = module.networking.vpc_id
  private_subnet_id_1 = module.networking.private_subnet_1
  private_subnet_id_2 = module.networking.private_subnet_2
  public_subnet_id    = module.networking.public_subnet_1
  public_subnet_id_2  = module.networking.private_subnet_2
  project_name        = var.project_name
}
