output "db_identifier" {
  value       = aws_db_instance.default.identifier
  description = "Database instance"
}
