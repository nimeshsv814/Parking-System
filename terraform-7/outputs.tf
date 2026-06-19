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

output "payment_invoice_bucket_name" {
  value = aws_s3_bucket.payment_invoices.bucket
}

output "payment_invoice_kms_key_arn" {
  value = aws_kms_key.payment_invoices.arn
}

output "app_config_secret_arn" {
  value = aws_secretsmanager_secret.app_config.arn
}

output "notification_queue_url" {
  value = aws_sqs_queue.notification.url
}

output "booking_sns_topics" {
  value = {
    confirmed = aws_sns_topic.booking_confirmed.arn
    cancelled = aws_sns_topic.booking_cancelled.arn
  }
}

output "observability_sns_topic_arn" {
  value = aws_sns_topic.observability_alerts.arn
}

output "cloudwatch_dashboard_name" {
  value = aws_cloudwatch_dashboard.quickslot.dashboard_name
}

output "cloudwatch_log_groups" {
  value = {
    for service, log_group in aws_cloudwatch_log_group.app_services : service => log_group.name
  }
}

output "cloudwatch_alarm_names" {
  value = concat(
    [
      aws_cloudwatch_metric_alarm.notification_dlq_visible_messages.alarm_name,
      aws_cloudwatch_metric_alarm.notification_queue_oldest_message.alarm_name,
      aws_cloudwatch_metric_alarm.booking_confirmed_sns_failed.alarm_name,
      aws_cloudwatch_metric_alarm.booking_cancelled_sns_failed.alarm_name
    ],
    [for alarm in aws_cloudwatch_metric_alarm.dynamodb_throttled_requests : alarm.alarm_name],
    [for alarm in aws_cloudwatch_metric_alarm.dynamodb_system_errors : alarm.alarm_name]
  )
}

output "eventbridge_rule_names" {
  value = concat(
    [
      aws_cloudwatch_event_rule.eks_cluster_state_change.name,
      aws_cloudwatch_event_rule.eks_node_group_state_change.name
    ],
    var.enable_invoice_eventbridge_notifications ? [aws_cloudwatch_event_rule.payment_invoice_pdf_created[0].name] : []
  )
}

output "vpc_endpoint_ids" {
  value = {
    interface = { for name, endpoint in aws_vpc_endpoint.interface : name => endpoint.id }
    gateway   = { for name, endpoint in aws_vpc_endpoint.gateway : name => endpoint.id }
  }
}

output "cloudfront_domain_name" {
  value = var.enable_edge_stack ? aws_cloudfront_distribution.edge[0].domain_name : null
}

output "route53_name_servers" {
  value = local.create_route53_hosted_zone ? aws_route53_zone.edge[0].name_servers : []
}
