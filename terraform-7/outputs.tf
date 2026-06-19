output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "namespace" {
  value = kubernetes_namespace.quickslot.metadata[0].name
}

output "dynamodb_tables" {
  value = {
    auth_users    = aws_dynamodb_table.auth_users.name
    parking_slots = aws_dynamodb_table.parking_slots.name
    bookings      = aws_dynamodb_table.bookings.name
    payments      = aws_dynamodb_table.payments.name
    notifications = aws_dynamodb_table.notifications.name
  }
}

output "alb_hostname" {
  description = "Run terraform refresh or terraform apply again if this is initially empty while the AWS Load Balancer Controller reconciles."
  value       = try(kubernetes_ingress_v1.alb.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}
