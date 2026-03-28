# Networking module - creates the VPC, subnets, gateways, and route tables.
# Traffic flow:
#   Internet -> IGW -> Public subnets (ALB) -> NAT GW -> Private subnets (ECS tasks)

# VPC - isolated virtual network containing all resources.
# DNS enabled so ECS/ECR can resolve each other by hostname.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "cloud-suite-vpc"
  }
}

# Internet Gateway - gives public subnets a route to the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "my-igw"
  }
}

# Public subnets (2 AZs) - ALB and NAT Gateway live here.
# map_public_ip_on_launch = true assigns public IPs automatically.
resource "aws_subnet" "public_subnet_1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "cloud-suite-public-subnet-1"
    }
}

resource "aws_subnet" "public_subnet_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    tags = {
        Name = "cloud-suite-public-subnet-2"
    }
}

# Private subnets (2 AZs) - ECS Fargate tasks run here.
# No public IPs; outbound internet access goes through NAT Gateway.
resource "aws_subnet" "private_subnet_1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = false
    tags = {
        Name = "cloud-suite-private-subnet-1"
    }
}

resource "aws_subnet" "private_subnet_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.4.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = false
    tags = {
        Name = "cloud-suite-private-subnet-2"
    }
}

# Public route table - sends all outbound traffic (0.0.0.0/0) to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "cloud-suite-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

# Private route table - outbound traffic routed through NAT Gateway (added below)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "cloud-suite-private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private.id
}

# Elastic IP + NAT Gateway - allows private subnets to reach the internet
# outbound (e.g., pulling Docker images) without being publicly accessible.
# NAT GW sits in a public subnet and needs the IGW to exist first.
resource "aws_eip" "cloud_suite_eip" {
  domain = "vpc"

  tags = {
    Name = "cloud-suite-eip"
  }
}

resource "aws_nat_gateway" "main_nat_gw" {
  allocation_id = aws_eip.cloud_suite_eip.id
  subnet_id = aws_subnet.public_subnet_1.id

  tags = {
    Name = "main_nat_gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Default route for private subnets -> NAT Gateway
resource "aws_route" "nat_route" {
  route_table_id = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main_nat_gw.id
}
