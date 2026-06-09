output "bastion_security_group_id" {
  value = aws_security_group.bastion-host-sg.id
}

output "external_alb_security_group_id" {
  value = aws_security_group.externalALB-sg.id
}

output "web_security_group_id" {
  value = aws_security_group.web-sg.id
}

output "internal_alb_security_group_id" {
  value = aws_security_group.internalALB-sg.id
}

output "app_security_group_id" {
  value = aws_security_group.app-sg.id
}

output "db_security_group_id" {
  value = aws_security_group.db-sg.id
}
