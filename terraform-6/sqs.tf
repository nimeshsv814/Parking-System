resource "aws_sqs_queue" "notification_dlq" {
  count = var.create_sqs_notification_queue ? 1 : 0

  name                       = "${var.sqs_notification_queue_name}-dlq"
  message_retention_seconds  = var.sqs_notification_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_notification_receive_wait_time_seconds
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = var.sqs_notification_visibility_timeout_seconds

  tags = {
    Name        = "${var.sqs_notification_queue_name}-dlq"
    Service     = "notification-service"
    Application = "smart-parking"
  }
}

resource "aws_sqs_queue" "notification" {
  count = var.create_sqs_notification_queue ? 1 : 0

  name                       = var.sqs_notification_queue_name
  delay_seconds              = 0
  message_retention_seconds  = var.sqs_notification_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_notification_receive_wait_time_seconds
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = var.sqs_notification_visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq[0].arn
    maxReceiveCount     = var.sqs_notification_max_receive_count
  })

  tags = {
    Name        = var.sqs_notification_queue_name
    Service     = "notification-service"
    Application = "smart-parking"
  }
}

locals {
  effective_sqs_notification_queue_name = var.create_sqs_notification_queue ? aws_sqs_queue.notification[0].name : var.sqs_notification_queue_name
  effective_sqs_notification_queue_url  = var.create_sqs_notification_queue ? aws_sqs_queue.notification[0].url : var.sqs_notification_queue_url
  effective_sqs_notification_queue_arn  = var.create_sqs_notification_queue ? aws_sqs_queue.notification[0].arn : var.sqs_notification_queue_arn
}
