variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "quickslot-eks"
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
  default = "docker.io/nimeshsv814/tf-booking-service:v6.0.8"
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
