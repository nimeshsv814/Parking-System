variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  type = map(string)
  default = {
    web-public-subnet-1a = "10.0.1.0/24"
    web-public-subnet-1b = "10.0.2.0/24"
  }
}

variable "app_private_subnets" {
  type = map(string)
  default = {
    app-private-subnet-1a = "10.0.3.0/24"
    app-private-subnet-1b = "10.0.4.0/24"
  }
}

variable "db_private_subnets" {
  type = map(string)
  default = {
    data-private-subnet-1a = "10.0.5.0/24"
    data-private-subnet-1b = "10.0.6.0/24"
  }
}

variable "ssh_port" {
  type    = number
  default = 22
}

variable "http_port" {
  type    = number
  default = 80
}

variable "app_port" {
  type    = number
  default = 4000
}

variable "db_port" {
  type    = number
  default = 27017
}

variable "backend_from" {
  type    = number
  default = 4001
}

variable "backend_to" {
  type    = number
  default = 4006
}

variable "ami_id" {
  type    = string
  default = "ami-091138d0f0d41ff90"
}

variable "key_name" {
  type    = string
  default = "three-tier-arch"
}

variable "web_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "web_min_size" {
  type    = number
  default = 1
}

variable "web_max_size" {
  type    = number
  default = 1
}

variable "web_desired_capacity" {
  type    = number
  default = 1
}

variable "app_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "app_min_size" {
  type    = number
  default = 1
}

variable "app_max_size" {
  type    = number
  default = 1
}

variable "app_desired_capacity" {
  type    = number
  default = 1
}

variable "frontend_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-frontend:v3.0.0"
}

variable "auth_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-auth-service:v4.0.0"
}

variable "parking_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-parking-service:v4.0.0"
}

variable "booking_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-booking-service:v4.0.0"
}

variable "payment_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-payment-service:v4.0.0"
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
  type        = string
  description = "DynamoDB table name for auth users"
  default     = "smart-parking-users"
}

variable "parking_slots_table" {
  type        = string
  description = "DynamoDB table name for parking slots"
  default     = "smart-parking-slots"
}

variable "booking_table" {
  type        = string
  description = "DynamoDB table name for bookings"
  default     = "smart-parking-bookings"
}

variable "payment_table" {
  type        = string
  description = "DynamoDB table name for payments"
  default     = "smart-parking-payments"
}

variable "notification_table" {
  type        = string
  description = "DynamoDB table name for notifications"
  default     = "smart-parking-notifications"
}

variable "sqs_notification_queue_name" {
  type        = string
  description = "Manually created SQS queue name for notification events"
  default     = "smart-parking-notifications-queue"
}

variable "sqs_notification_queue_url" {
  type        = string
  description = "Manually created SQS queue URL for notification events"
  default     = ""
}

variable "sqs_notification_queue_arn" {
  type        = string
  description = "Manually created SQS queue ARN for notification events"
  default     = "arn:aws:sqs:us-east-1:*:smart-parking-notifications-queue"
}

variable "app_config_secret_arn" {
  type        = string
  description = "Optional AWS Secrets Manager secret ARN containing app runtime secrets as JSON"
  default     = ""
}

variable "enable_edge_stack" {
  type        = bool
  description = "Set true to create Route53, WAF, and CloudFront edge resources"
  default     = false
}

variable "enable_acm" {
  type        = bool
  description = "Set true to let Terraform create ACM and attach app_domain_name to CloudFront"
  default     = false
}

variable "existing_acm_certificate_arn" {
  type        = string
  description = "Existing ACM certificate ARN in us-east-1 for app_domain_name. Leave blank to skip manual ACM."
  default     = ""

  validation {
    condition     = var.existing_acm_certificate_arn == "" || can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/.+", var.existing_acm_certificate_arn))
    error_message = "existing_acm_certificate_arn must be blank or an ACM certificate ARN from us-east-1."
  }
}

variable "route53_hosted_zone_id" {
  type        = string
  description = "Existing Route53 public hosted zone ID. Leave blank when create_route53_hosted_zone is true."
  default     = ""
}

variable "app_domain_name" {
  type        = string
  description = "Custom domain name for the app, for example parking.example.com"
  default     = ""
}

variable "create_route53_hosted_zone" {
  type        = bool
  description = "Create a Route53 public hosted zone for route53_zone_domain_name"
  default     = false
}

variable "route53_zone_domain_name" {
  type        = string
  description = "Root domain for the Route53 hosted zone, for example quickslot.site"
  default     = ""
}

variable "app_domain_subject_alternative_names" {
  type        = list(string)
  description = "Optional additional domain names for the CloudFront ACM certificate"
  default     = []
}

variable "cloudfront_price_class" {
  type        = string
  description = "CloudFront price class"
  default     = "PriceClass_100"
}

variable "cloudfront_create_ipv6_record" {
  type        = bool
  description = "Create Route53 AAAA alias record for CloudFront"
  default     = true
}

variable "waf_rate_limit" {
  type        = number
  description = "Maximum requests from a single IP in a 5-minute window before WAF blocks"
  default     = 2000
}

variable "cloudfront_origin_custom_header_name" {
  type        = string
  description = "Optional custom header name CloudFront sends to the ALB origin"
  default     = ""
}

variable "cloudfront_origin_custom_header_value" {
  type        = string
  description = "Optional custom header value CloudFront sends to the ALB origin"
  default     = ""
  sensitive   = true
}
