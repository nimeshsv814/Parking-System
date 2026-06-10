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

resource "aws_sns_topic_subscription" "booking_confirmed_email" {
  for_each = toset(var.booking_confirmed_email_subscribers)

  topic_arn = aws_sns_topic.booking_confirmed.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "booking_cancelled_email" {
  for_each = toset(var.booking_cancelled_email_subscribers)

  topic_arn = aws_sns_topic.booking_cancelled.arn
  protocol  = "email"
  endpoint  = each.value
}
