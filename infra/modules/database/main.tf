resource "aws_db_subnet_group" "database_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [var.private_subnet_1, var.private_subnet_2]

  tags = {
    Name = "My DB Subnet Group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow inbound traffic to RDS"
  vpc_id      = var.vpc_id # Replace with your VPC ID

  ingress {
    from_port       = 5432 # Example for PostgreSQL; use 3306 for MySQL
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group] # Only allow access from ECS
  }
}

resource "aws_db_instance" "default" {
  identifier             = "${var.project_name}-db-instance"
  allocated_storage      = 20
  db_name                = "cloudsuitedb"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password # Use secrets manager for production!
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.database_subnet_group.name
  skip_final_snapshot    = true
}
