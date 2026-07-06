# The primary endpoint address the API connects to. Feed this into the ECS task
# definition's REDIS_ADDR environment variable (host:port).
output "redis_endpoint" {
  description = "Redis primary endpoint hostname"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].port
}

output "redis_addr" {
  description = "Redis host:port for the API's REDIS_ADDR env var"
  value       = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"
}

output "redis_security_group_id" {
  description = "Redis security group ID (root wires the ECS ingress rule)"
  value       = aws_security_group.redis_sg.id
}
