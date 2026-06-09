output "external_alb_dns" {
  description = "DNS name of the public application load balancer"
  value       = module.load_balancers.external_alb_dns
}

output "internal_alb_dns" {
  description = "DNS name of the internal application load balancer"
  value       = module.load_balancers.internal_alb_dns
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID when edge stack is enabled"
  value       = try(module.cdn[0].distribution_id, null)
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name when edge stack is enabled"
  value       = try(module.cdn[0].domain_name, null)
}

output "app_domain_name" {
  description = "Route53 application domain when edge stack is enabled"
  value       = var.enable_edge_stack ? var.app_domain_name : null
}

output "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID used by the edge stack"
  value       = var.enable_edge_stack || var.create_route53_hosted_zone ? local.edge_hosted_zone_id : null
}

output "route53_name_servers" {
  description = "Name servers to set at your domain registrar when Terraform creates the hosted zone"
  value       = try(aws_route53_zone.edge[0].name_servers, null)
}
