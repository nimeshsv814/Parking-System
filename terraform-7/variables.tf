variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "quickslot-eks"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "ubuntu_eks_release" {
  description = "Ubuntu release for EKS worker nodes. EKS 1.30 supports jammy/22.04."
  type        = string
  default     = "22.04"
}

variable "ubuntu_eks_arch" {
  description = "Ubuntu EKS worker node architecture."
  type        = string
  default     = "amd64"
}

variable "ubuntu_eks_volume_type" {
  description = "Ubuntu EKS AMI volume family in Canonical SSM Parameter Store."
  type        = string
  default     = "ebs-gp2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.70.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.70.1.0/24", "10.70.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.70.11.0/24", "10.70.12.0/24"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "namespace" {
  type    = string
  default = "quickslot"
}

variable "frontend_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-frontend:v6.0.8"
}

variable "auth_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-auth-service:v4.0.0"
}

variable "parking_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-parking-service:v5.0.0"
}

variable "booking_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-booking-service:v7.0.1"
}

variable "payment_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-payment-service:v6.0.6"
}

variable "scheduler_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-scheduler-service:latest"
}

variable "notification_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-notification-service:v4.0.0"
}

variable "auth_users_table" {
  type    = string
  default = "smart-parking-users-eks"
}

variable "parking_slots_table" {
  type    = string
  default = "smart-parking-slots-eks"
}

variable "booking_table" {
  type    = string
  default = "smart-parking-bookings-eks"
}

variable "payment_table" {
  type    = string
  default = "smart-parking-payments-eks"
}

variable "notification_table" {
  type    = string
  default = "smart-parking-notifications-eks"
}

variable "enable_dynamodb_point_in_time_recovery" {
  type    = bool
  default = true
}

variable "enable_dynamodb_deletion_protection" {
  type    = bool
  default = false
}

variable "jwt_secret" {
  type      = string
  default   = "smartparking_super_secret"
  sensitive = true
}

variable "internal_api_key" {
  type      = string
  default   = "smartparking_internal_key"
  sensitive = true
}

variable "seed_admin_email" {
  type    = string
  default = "admin@parking.com"
}

variable "seed_admin_password" {
  type      = string
  default   = "Admin@123"
  sensitive = true
}

variable "seed_user_email" {
  type    = string
  default = "user@parking.com"
}

variable "seed_user_password" {
  type      = string
  default   = "User@123"
  sensitive = true
}

variable "razorpay_key_id" {
  type    = string
  default = "rzp_test_ShFFMxa9JkqmZu"
}

variable "razorpay_key_secret" {
  type      = string
  default   = "1I4sLVIvCMWSTUlM5lCZm71j"
  sensitive = true
}

variable "razorpay_currency" {
  type    = string
  default = "INR"
}

variable "gemini_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "gemini_model" {
  type    = string
  default = "gemini-2.5-flash"
}

variable "payment_invoice_bucket_name" {
  description = "Optional S3 bucket name for booking/payment invoice PDFs. Leave blank to generate an account and region scoped name."
  type        = string
  default     = ""
}

variable "payment_invoice_bucket_force_destroy" {
  description = "Allow Terraform to delete the invoice bucket even when it contains objects."
  type        = bool
  default     = false
}

variable "payment_invoice_kms_key_deletion_window_in_days" {
  description = "KMS key deletion window for the payment invoice key."
  type        = number
  default     = 7
}

variable "app_config_secret_name" {
  description = "Secrets Manager secret name for QuickSlot EKS runtime configuration."
  type        = string
  default     = "quickslot-07"
}

variable "app_config_secret_recovery_window_in_days" {
  description = "Recovery window in days before Terraform-deleted app config secrets are permanently deleted."
  type        = number
  default     = 7
}

variable "manage_app_config_secret_value" {
  description = "Create/update the app runtime JSON value in Secrets Manager. Secret values are stored in Terraform state when enabled."
  type        = bool
  default     = false
}

variable "sqs_notification_queue_name" {
  description = "SQS queue name for notification events."
  type        = string
  default     = "smart-parking-notifications-eks-queue"
}

variable "sqs_notification_visibility_timeout_seconds" {
  type    = number
  default = 60
}

variable "sqs_notification_message_retention_seconds" {
  type    = number
  default = 345600
}

variable "sqs_notification_receive_wait_time_seconds" {
  type    = number
  default = 10
}

variable "sqs_notification_max_receive_count" {
  type    = number
  default = 5
}

variable "booking_confirmed_sns_topic_name" {
  type    = string
  default = "quickslot-eks-booking-confirmed"
}

variable "booking_cancelled_sns_topic_name" {
  type    = string
  default = "quickslot-eks-booking-cancelled"
}

variable "observability_sns_topic_name" {
  type    = string
  default = "quickslot-eks-observability-alerts"
}

variable "observability_alert_email_subscribers" {
  description = "Email addresses subscribed to CloudWatch/EventBridge observability alerts. AWS sends confirmation emails."
  type        = list(string)
  default     = []
}

variable "cloudwatch_log_retention_days" {
  description = "Retention period for QuickSlot CloudWatch log groups."
  type        = number
  default     = 14
}

variable "sqs_dlq_visible_alarm_threshold" {
  description = "Alarm when the notification DLQ has at least this many visible messages."
  type        = number
  default     = 1
}

variable "sqs_oldest_message_age_alarm_seconds" {
  description = "Alarm when the notification queue oldest message age reaches this value."
  type        = number
  default     = 300
}

variable "dynamodb_throttled_requests_alarm_threshold" {
  description = "Alarm threshold for DynamoDB ThrottledRequests."
  type        = number
  default     = 1
}

variable "enable_invoice_eventbridge_notifications" {
  description = "Publish S3 invoice PDF creation events to the observability SNS topic through EventBridge."
  type        = bool
  default     = true
}

variable "enable_edge_stack" {
  description = "Create CloudFront, WAF, and optional Route53 DNS in front of the ALB. Requires cloudfront_origin_domain_name."
  type        = bool
  default     = false
}

variable "cloudfront_origin_domain_name" {
  description = "ALB DNS name used as the CloudFront origin, without http:// or https://."
  type        = string
  default     = ""
}

variable "app_domain_name" {
  description = "Optional custom app domain for CloudFront, such as app.example.com."
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for app_domain_name."
  type        = string
  default     = ""
}

variable "route53_hosted_zone_id" {
  description = "Existing Route53 hosted zone ID. Leave blank when create_route53_hosted_zone is true."
  type        = string
  default     = ""
}

variable "create_route53_hosted_zone" {
  description = "Create a Route53 public hosted zone for route53_zone_domain_name."
  type        = bool
  default     = false
}

variable "route53_zone_domain_name" {
  description = "Domain name for the Route53 hosted zone when create_route53_hosted_zone is true."
  type        = string
  default     = ""
}

variable "create_cloudfront_route53_alias_record" {
  description = "Create Route53 A/AAAA alias records for app_domain_name pointing to CloudFront."
  type        = bool
  default     = false
}

variable "cloudfront_create_ipv6_record" {
  type    = bool
  default = true
}

variable "cloudfront_price_class" {
  type    = string
  default = "PriceClass_100"
}

variable "waf_rate_limit" {
  description = "Maximum requests per 5 minutes per IP before WAF blocks."
  type        = number
  default     = 2000
}

variable "cloudfront_origin_custom_header_name" {
  type    = string
  default = ""
}

variable "cloudfront_origin_custom_header_value" {
  type      = string
  default   = ""
  sensitive = true
}
