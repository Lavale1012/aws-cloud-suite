# Root module - configures AWS provider and calls networking + compute modules.
# Flow: networking creates VPC/subnets -> outputs feed into compute module.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = "cloud-suite-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloud-suite-terraform-locks"
    encrypt        = true
  }
}


provider "aws" {
  region = var.aws_region
}

# Creates VPC, subnets, IGW, NAT gateway, and route tables
module "networking" {
  source       = "./modules/networking"
  vpc_cidr     = var.vpc_cidr
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
  public_subnet_id_2  = module.networking.public_subnet_2
  project_name        = var.project_name
  jwt_secret          = var.jwt_secret
  redis_addr          = module.redis.redis_addr
  db_username         = var.db_username
  db_password         = var.db_password
}

module "database" {
  source             = "./modules/database"
  vpc_id             = module.networking.vpc_id
  private_subnet_1   = module.networking.private_subnet_1
  private_subnet_2   = module.networking.private_subnet_2
  ecs_security_group = module.compute.ecs_security_group_id
  project_name       = var.project_name
  db_username        = var.db_username
  db_password        = var.db_password
}

# ElastiCache Redis for the API's cross-instance rate limiter.
# NOTE: this module intentionally does NOT take the ECS security group, so it has
# no dependency on the compute module (compute consumes redis.redis_addr below).
# The ECS→Redis ingress allowance is added as a standalone rule after both exist.
module "redis" {
  source           = "./modules/redis"
  vpc_id           = module.networking.vpc_id
  private_subnet_1 = module.networking.private_subnet_1
  private_subnet_2 = module.networking.private_subnet_2
  project_name     = var.project_name
}

# Allow the ECS tasks to reach Redis on 6379. Declared at the root so it can
# reference both module security groups without creating a compute<->redis cycle.
resource "aws_security_group_rule" "ecs_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.redis.redis_security_group_id
  source_security_group_id = module.compute.ecs_security_group_id
}

module "monitoring" {
  source                 = "./modules/monitoring"
  project_name           = var.project_name
  ecs_cluster_name       = module.compute.ecs_cluster_name
  ecs_service_name       = module.compute.ecs_service_name
  alb_arn_suffix         = module.compute.alb_arn_suffix
  db_instance_identifier = module.database.db_identifier
  notification_email     = var.notification_email
}
