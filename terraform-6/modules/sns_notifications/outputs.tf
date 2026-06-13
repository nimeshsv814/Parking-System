output "booking_confirmed_topic_arn" {
  value = aws_sns_topic.booking_confirmed.arn
}

output "booking_cancelled_topic_arn" {
  value = aws_sns_topic.booking_cancelled.arn
}

output "booking_confirmed_topic_name" {
  value = aws_sns_topic.booking_confirmed.name
}

output "booking_cancelled_topic_name" {
  value = aws_sns_topic.booking_cancelled.name
}

output "sqs_subscription_enabled" {
  value = local.create_sqs_subscription
}
