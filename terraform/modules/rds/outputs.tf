output "endpoint"         { value = aws_db_instance.main.address }
output "port"             { value = aws_db_instance.main.port }
output "db_name"          { value = aws_db_instance.main.db_name }
output "db_instance_id"   { value = aws_db_instance.main.id } # Ready for Phase 5 Read Replica
output "db_instance_arn"  { value = aws_db_instance.main.arn }