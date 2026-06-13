variable "aws_region" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "app_instance_type" {
  type = string
}

variable "app_min_size" {
  type = number
}

variable "app_max_size" {
  type = number
}

variable "app_desired_capacity" {
  type = number
}

variable "app_config_secret_arn" {
  type = string
}

variable "app_private_subnet_ids" {
  type = list(string)
}

variable "app_security_group_id" {
  type = string
}

variable "app_target_group_arn" {
  type = string
}

variable "service_target_group_arns" {
  type = list(string)
}

variable "auth_service_image" {
  type = string
}

variable "parking_service_image" {
  type = string
}

variable "booking_service_image" {
  type = string
}

variable "payment_service_image" {
  type = string
}

variable "scheduler_service_image" {
  type = string
}

variable "notification_service_image" {
  type = string
}

variable "auth_users_table" {
  type = string
}

variable "parking_slots_table" {
  type = string
}

variable "booking_table" {
  type = string
}

variable "booking_confirmed_sns_topic_arn" {
  type = string
}

variable "booking_cancelled_sns_topic_arn" {
  type = string
}

variable "payment_table" {
  type = string
}

variable "payment_invoice_bucket_name" {
  type = string
}

variable "payment_invoice_bucket_arn" {
  type = string
}

variable "payment_invoice_kms_key_arn" {
  type = string
}

variable "notification_table" {
  type = string
}

variable "dynamodb_table_arns" {
  type = list(string)
}

variable "dynamodb_table_index_arns" {
  type = list(string)
}

variable "sqs_notification_queue_name" {
  type = string
}

variable "sqs_notification_queue_url" {
  type = string
}

variable "sqs_notification_queue_arn" {
  type = string
}
