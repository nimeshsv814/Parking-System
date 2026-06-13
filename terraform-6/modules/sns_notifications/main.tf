resource "aws_sns_topic" "booking_confirmed" {
  name         = var.booking_confirmed_topic_name
  display_name = "Booking Confirmed"

  tags = {
    Name = var.booking_confirmed_topic_name
  }
}

resource "aws_sns_topic" "booking_cancelled" {
  name         = var.booking_cancelled_topic_name
  display_name = "Booking Cancelled"

  tags = {
    Name = var.booking_cancelled_topic_name
  }
}

locals {
  create_sqs_subscription = var.enable_sqs_subscription
  booking_topic_arns = [
    aws_sns_topic.booking_confirmed.arn,
    aws_sns_topic.booking_cancelled.arn
  ]
}

resource "aws_sns_topic_subscription" "booking_confirmed_email" {
  for_each = toset(var.booking_confirmed_email_subscribers)

  topic_arn = aws_sns_topic.booking_confirmed.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "booking_confirmed_sqs" {
  count = local.create_sqs_subscription ? 1 : 0

  topic_arn            = aws_sns_topic.booking_confirmed.arn
  protocol             = "sqs"
  endpoint             = var.notification_queue_arn
  raw_message_delivery = true
}

resource "aws_sns_topic_subscription" "booking_cancelled_sqs" {
  count = local.create_sqs_subscription ? 1 : 0

  topic_arn            = aws_sns_topic.booking_cancelled.arn
  protocol             = "sqs"
  endpoint             = var.notification_queue_arn
  raw_message_delivery = true
}

resource "aws_sqs_queue_policy" "allow_booking_sns" {
  count = local.create_sqs_subscription ? 1 : 0

  queue_url = var.notification_queue_url

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
        Resource = var.notification_queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = local.booking_topic_arns
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "booking_cancelled_email" {
  for_each = toset(var.booking_cancelled_email_subscribers)

  topic_arn = aws_sns_topic.booking_cancelled.arn
  protocol  = "email"
  endpoint  = each.value
}
