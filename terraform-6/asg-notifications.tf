locals {
  asg_notification_group_names = [
    module.app_tier.autoscaling_group_name,
    module.web_tier.autoscaling_group_name
  ]
}

resource "aws_sns_topic" "asg_notifications" {
  count = var.enable_asg_email_notifications ? 1 : 0

  name         = var.asg_notification_topic_name
  display_name = "Smart Parking ASG EC2 Notifications"

  tags = {
    Name = var.asg_notification_topic_name
  }
}

resource "aws_sns_topic_subscription" "asg_email" {
  count = var.enable_asg_email_notifications ? 1 : 0

  topic_arn = aws_sns_topic.asg_notifications[0].arn
  protocol  = "email"
  endpoint  = var.asg_notification_email
}

resource "aws_autoscaling_notification" "asg_ec2_events" {
  count = var.enable_asg_email_notifications ? 1 : 0

  group_names = local.asg_notification_group_names

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]

  topic_arn = aws_sns_topic.asg_notifications[0].arn
}
