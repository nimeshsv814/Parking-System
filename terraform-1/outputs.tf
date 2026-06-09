output "external_alb_dns" {
  description = "DNS name of the public application load balancer"
  value       = aws_lb.external_alb.dns_name
}

output "internal_alb_dns" {
  description = "DNS name of the internal application load balancer"
  value       = aws_lb.internal_alb.dns_name
}
