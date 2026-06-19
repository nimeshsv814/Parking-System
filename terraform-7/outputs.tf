output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "namespace" {
  value = var.namespace
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

output "app_pods_role_arn" {
  description = "Use this ARN in Helm values as serviceAccount.annotations.eks.amazonaws.com/role-arn."
  value       = aws_iam_role.app_pods.arn
}

output "public_subnet_ids" {
  description = "Use these subnet IDs in Helm values ingress.subnets so the AWS Load Balancer Controller creates the public ALB."
  value       = aws_subnet.public[*].id
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

output "helm_install_hint" {
  value = "helm upgrade --install quickslot ../infra/helm/quickslot --namespace ${var.namespace} --create-namespace --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${aws_iam_role.app_pods.arn} --set ingress.subnets={${join(",", aws_subnet.public[*].id)}}"
}
