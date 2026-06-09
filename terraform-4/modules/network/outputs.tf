output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = { for name, subnet in aws_subnet.public_subnets : name => subnet.id }
}

output "app_private_subnet_ids" {
  value = { for name, subnet in aws_subnet.app_private_subnets : name => subnet.id }
}

output "db_private_subnet_ids" {
  value = { for name, subnet in aws_subnet.db_private_subnets : name => subnet.id }
}
