output "external_alb_dns" {
  description = "DNS name of the public application load balancer"
  value       = module.load_balancers.external_alb_dns
}

output "internal_alb_dns" {
  description = "DNS name of the internal application load balancer"
  value       = module.load_balancers.internal_alb_dns
}
