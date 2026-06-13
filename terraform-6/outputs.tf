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

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID to use for manual Route53 alias records"
  value       = try(module.cdn[0].hosted_zone_id, null)
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN attached to CloudFront when edge stack is enabled"
  value       = try(module.waf[0].web_acl_arn, null)
}

output "cloudfront_custom_domain_enabled" {
  description = "True only when Terraform is managing the CloudFront custom domain"
  value       = local.cloudfront_custom_domain_enabled
}

output "app_domain_name" {
  description = "Route53 application domain when edge stack is enabled"
  value       = var.enable_edge_stack ? var.app_domain_name : null
}

output "app_domain_route53_target" {
  description = "Terraform-managed DNS target for app_domain_name. Null when Route53 alias is handled manually."
  value       = local.create_cloudfront_dns_record ? module.cdn[0].domain_name : null
}

output "cloudfront_route53_alias_record_created" {
  description = "True when Terraform created the app_domain_name A/AAAA alias records to CloudFront"
  value       = local.create_cloudfront_dns_record
}

output "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID used by the edge stack"
  value       = var.enable_edge_stack ? local.edge_hosted_zone_id : null
}

output "route53_name_servers" {
  description = "Name servers to set at your domain registrar when Terraform creates the hosted zone"
  value       = try(aws_route53_zone.edge[0].name_servers, null)
}

output "app_config_secret_arn" {
  description = "Secrets Manager ARN used by the app tier for runtime secrets"
  value       = local.app_config_secret_arn != "" ? local.app_config_secret_arn : null
}

output "app_config_secret_name" {
  description = "Secrets Manager secret name created by Terraform when create_app_config_secret is true"
  value       = try(module.app_config_secret[0].secret_name, null)
}

output "dynamodb_tables" {
  description = "DynamoDB tables created for each Smart Parking microservice"
  value = {
    auth_users = {
      name      = aws_dynamodb_table.auth_users.name
      arn       = aws_dynamodb_table.auth_users.arn
      hash_key  = "userId"
      gsi_names = ["role-createdAt-index"]
    }
    parking_slots = {
      name      = aws_dynamodb_table.parking_slots.name
      arn       = aws_dynamodb_table.parking_slots.arn
      hash_key  = "slotId"
      gsi_names = ["status-location-index", "bookingId-index"]
    }
    bookings = {
      name      = aws_dynamodb_table.bookings.name
      arn       = aws_dynamodb_table.bookings.arn
      hash_key  = "bookingId"
      gsi_names = ["userId-createdAt-index", "status-expiresAt-index", "slotId-createdAt-index"]
    }
    payments = {
      name      = aws_dynamodb_table.payments.name
      arn       = aws_dynamodb_table.payments.arn
      hash_key  = "paymentId"
      gsi_names = ["userId-createdAt-index", "bookingId-createdAt-index", "razorpayOrderId-index"]
    }
    notifications = {
      name      = aws_dynamodb_table.notifications.name
      arn       = aws_dynamodb_table.notifications.arn
      hash_key  = "notificationId"
      gsi_names = ["recipientUserId-createdAt-index", "bookingId-createdAt-index"]
    }
  }
}

output "sqs_notification_queue" {
  description = "SQS notification queue connected to booking SNS topics and backend services"
  value = {
    name = local.effective_sqs_notification_queue_name
    url  = local.effective_sqs_notification_queue_url
    arn  = local.effective_sqs_notification_queue_arn
    dlq = var.create_sqs_notification_queue ? {
      name = aws_sqs_queue.notification_dlq[0].name
      url  = aws_sqs_queue.notification_dlq[0].url
      arn  = aws_sqs_queue.notification_dlq[0].arn
    } : null
  }
}

output "booking_confirmed_sns_topic_arn" {
  description = "SNS topic ARN for booking confirmation user notifications"
  value       = try(module.booking_sns_notifications[0].booking_confirmed_topic_arn, null)
}

output "booking_cancelled_sns_topic_arn" {
  description = "SNS topic ARN for booking cancellation user notifications"
  value       = try(module.booking_sns_notifications[0].booking_cancelled_topic_arn, null)
}

output "booking_confirmed_sns_topic_name" {
  description = "SNS topic name for booking confirmation user notifications"
  value       = try(module.booking_sns_notifications[0].booking_confirmed_topic_name, null)
}

output "booking_cancelled_sns_topic_name" {
  description = "SNS topic name for booking cancellation user notifications"
  value       = try(module.booking_sns_notifications[0].booking_cancelled_topic_name, null)
}

output "booking_sns_to_sqs_subscription_enabled" {
  description = "True when booking SNS topics are subscribed to the notification SQS queue"
  value       = try(module.booking_sns_notifications[0].sqs_subscription_enabled, false)
}

output "asg_notification_topic_arn" {
  description = "SNS topic ARN for Auto Scaling Group EC2 launch and terminate notifications"
  value       = try(aws_sns_topic.asg_notifications[0].arn, null)
}

output "asg_notification_email" {
  description = "Email subscribed to Auto Scaling Group EC2 launch and terminate notifications"
  value       = var.enable_asg_email_notifications ? var.asg_notification_email : null
}

output "asg_notification_group_names" {
  description = "Auto Scaling Groups configured to send EC2 launch and terminate notifications"
  value       = var.enable_asg_email_notifications ? local.asg_notification_group_names : []
}
