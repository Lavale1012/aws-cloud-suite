# Redis module - ElastiCache (Redis) for the API's cross-instance rate limiter.
# Lives in private subnets and only accepts connections from the ECS security
# group, mirroring the database module's isolation.

# Subnet group - places the Redis nodes in the same private subnets as ECS/RDS.
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = [var.private_subnet_1, var.private_subnet_2]
}

# Security group for Redis. The ingress rule that allows the ECS tasks is added
# at the ROOT module level (as a standalone aws_security_group_rule), not here.
# This keeps the redis module free of any dependency on the compute module, so
# the two don't form a cycle — compute needs Redis's endpoint for REDIS_ADDR,
# and the ECS→Redis allowance is wired separately once both SGs exist.
resource "aws_security_group" "redis_sg" {
  name        = "${var.project_name}-redis-sg"
  description = "Redis security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-redis-sg"
  }
}

# ElastiCache Redis - single-node t3.micro is plenty for rate-limit counters.
# Rate-limit state is ephemeral (counters expire), so no snapshots are needed.
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  port                 = 6379
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
}
