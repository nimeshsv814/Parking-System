output "external_alb_dns" {
  value = aws_lb.external_alb.dns_name
}

output "internal_alb_dns" {
  value = aws_lb.internal_alb.dns_name
}

output "web_target_group_arn" {
  value = aws_lb_target_group.web_tg.arn
}

output "app_target_group_arn" {
  value = aws_lb_target_group.app_tg.arn
}

output "service_target_group_arns" {
  value = [for tg in aws_lb_target_group.service_tg : tg.arn]
}
