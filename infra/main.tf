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

module "networking" {
  source = "./modules/networking"
  vpc_cidr = var.vpc_cidr
  project_name = var.project_name

}

# module "compute" {
#   source = "./modules/compute"
#   vpc_id = module.networking.vpc_id
#   private_subnet_id_1 = module.networking.private_subnet_id_1
#   private_subnet_id_2 = module.networking.private_subnet_id_2
#   project_name = var.project_name
# }