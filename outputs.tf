output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}


############################
# Security Groups
############################
output "dev_web_sg_id" {
  description = "Web Security Group ID"
  value       = aws_security_group.dev_web_sg.id
}

output "dev_db_sg_id" {
  description = "Database Security Group ID"
  value       = aws_security_group.dev_db_sg.id
}

############################
# EC2 Instances
############################
output "dev_web_server_1_id" {
  description = "EC2 Web Server 1 ID"
  value       = aws_instance.dev_web_1.id
}

output "dev_web_server_1_public_ip" {
  description = "EC2 Web Server 1 Public IP"
  value       = aws_instance.dev_web_1.public_ip
}

output "dev_web_server_2_id" {
  description = "EC2 Web Server 2 ID"
  value       = aws_instance.dev_web_2.id
}

output "dev_web_server_2_public_ip" {
  description = "EC2 Web Server 2 Public IP"
  value       = aws_instance.dev_web_2.public_ip
}

############################
# RDS
############################
output "dev_rds_identifier" {
  description = "RDS MySQL Identifier"
  value       = aws_db_instance.dev_mysql.identifier
}

output "dev_rds_endpoint" {
  description = "RDS MySQL Endpoint"
  value       = aws_db_instance.dev_mysql.endpoint
}
