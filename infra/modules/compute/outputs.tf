output "vpc_id" {
  description = "This is the ID for the vpc"
  value = aws_vpc.main.id
}
output "private_subnet_id_1" {
description = "id for private subnet 1"
  value = aws_subnet.private_subnet_1.id
}

output "private_subnet_id_2" {
  description = "id for private subnet 2"
  value = aws_subnet.private_subnet_2.id
}

output "public_subnet_1" {
  description = "ID for public subnet 1"
  value       = aws_subnet.public_subnet_1.id
}

output "public_subnet_2" {
  description = "ID for public subnet 2"
  value       = aws_subnet.public_subnet_2.id
}