variable "booking_confirmed_topic_name" {
  type = string
}

variable "booking_cancelled_topic_name" {
  type = string
}

variable "booking_confirmed_email_subscribers" {
  type = list(string)
}

variable "booking_cancelled_email_subscribers" {
  type = list(string)
}

variable "enable_sqs_subscription" {
  type = bool
}

variable "notification_queue_arn" {
  type = string
}

variable "notification_queue_url" {
  type = string
}
