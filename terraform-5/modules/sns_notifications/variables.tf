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
