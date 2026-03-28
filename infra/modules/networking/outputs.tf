# Outputs consumed by the compute module via the root module.
# Networking outputs -> root main.tf -> compute module inputs.

output "vpc_id" {
  description = "This is the ID for the vpc"
  value = aws_vpc.main.id
}

output "private_subnet_1" {
  description = "This is the ID for private subnet 1"
  value = aws_subnet.private_subnet_1.id
}

output "private_subnet_2" {
  description = "This is the ID for private subnet 2"
  value = aws_subnet.private_subnet_2.id
}

output "public_subnet_1" {
  description = "This is the ID for public subnet 1"
  value = aws_subnet.public_subnet_1.id
}

output "public_subnet_2" {
  description = "This is the ID for public subnet 2"
  value = aws_subnet.public_subnet_2.id
}
