output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of IDs of private application subnets"
  value       = aws_subnet.private_app[*].id
}

output "isolated_db_subnet_ids" {
  description = "List of IDs of isolated database subnets"
  value       = aws_subnet.isolated_db[*].id
}

# Route Table Outputs 

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of IDs of private application route tables"
  value       = aws_route_table.private_app[*].id
}

output "isolated_db_route_table_id" {
  description = "ID of the isolated database route table"
  value       = aws_route_table.isolated_db.id
}