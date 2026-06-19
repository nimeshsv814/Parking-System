resource "aws_sqs_queue" "notification_dlq" {
  name                       = "${var.sqs_notification_queue_name}-dlq"
  message_retention_seconds  = var.sqs_notification_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_notification_receive_wait_time_seconds
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = var.sqs_notification_visibility_timeout_seconds

  tags = {
    Name        = "${var.sqs_notification_queue_name}-dlq"
    Application = "smart-parking"
    Service     = "notification-service"
  }
}

resource "aws_sqs_queue" "notification" {
  name                       = var.sqs_notification_queue_name
  delay_seconds              = 0
  message_retention_seconds  = var.sqs_notification_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_notification_receive_wait_time_seconds
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = var.sqs_notification_visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = var.sqs_notification_max_receive_count
  })

  tags = {
    Name        = var.sqs_notification_queue_name
    Application = "smart-parking"
    Service     = "notification-service"
  }
}

resource "aws_sns_topic" "booking_confirmed" {
  name         = var.booking_confirmed_sns_topic_name
  display_name = "Booking Confirmed"

  tags = {
    Name        = var.booking_confirmed_sns_topic_name
    Application = "smart-parking"
  }
}

resource "aws_sns_topic" "booking_cancelled" {
  name         = var.booking_cancelled_sns_topic_name
  display_name = "Booking Cancelled"

  tags = {
    Name        = var.booking_cancelled_sns_topic_name
    Application = "smart-parking"
  }
}

resource "aws_sns_topic_subscription" "booking_confirmed_sqs" {
  topic_arn            = aws_sns_topic.booking_confirmed.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notification.arn
  raw_message_delivery = true
}

resource "aws_sns_topic_subscription" "booking_cancelled_sqs" {
  topic_arn            = aws_sns_topic.booking_cancelled.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notification.arn
  raw_message_delivery = true
}

resource "aws_sqs_queue_policy" "allow_booking_sns" {
  queue_url = aws_sqs_queue.notification.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBookingSnsToSendMessages"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.notification.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = [
              aws_sns_topic.booking_confirmed.arn,
              aws_sns_topic.booking_cancelled.arn
            ]
          }
        }
      }
    ]
  })
}
