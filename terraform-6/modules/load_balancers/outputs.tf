output "external_alb_dns" {
  value = aws_lb.external_alb.dns_name
}

output "external_alb_arn_suffix" {
  value = aws_lb.external_alb.arn_suffix
}

output "external_alb_zone_id" {
  value = aws_lb.external_alb.zone_id
}

output "internal_alb_dns" {
  value = aws_lb.internal_alb.dns_name
}

output "internal_alb_arn_suffix" {
  value = aws_lb.internal_alb.arn_suffix
}

output "web_target_group_arn" {
  value = aws_lb_target_group.web_tg.arn
}

output "web_target_group_arn_suffix" {
  value = aws_lb_target_group.web_tg.arn_suffix
}

output "app_target_group_arn" {
  value = aws_lb_target_group.app_tg.arn
}

output "app_target_group_arn_suffix" {
  value = aws_lb_target_group.app_tg.arn_suffix
}

output "service_target_group_arns" {
  value = [for tg in aws_lb_target_group.service_tg : tg.arn]
}

output "service_target_group_arn_suffixes" {
  value = { for name, tg in aws_lb_target_group.service_tg : name => tg.arn_suffix }
}
