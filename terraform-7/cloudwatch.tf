locals {
  app_log_group_names = {
    auth         = "/quickslot/eks/auth-service"
    parking      = "/quickslot/eks/parking-service"
    booking      = "/quickslot/eks/booking-service"
    payment      = "/quickslot/eks/payment-service"
    scheduler    = "/quickslot/eks/scheduler-service"
    notification = "/quickslot/eks/notification-service"
    frontend     = "/quickslot/eks/frontend"
  }

  observability_alarm_actions = [aws_sns_topic.observability_alerts.arn]
}

resource "aws_cloudwatch_log_group" "app_services" {
  for_each = local.app_log_group_names

  name              = each.value
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = each.value
    Application = "smart-parking"
    Service     = each.key
  }
}

resource "aws_sns_topic_subscription" "observability_alert_email" {
  for_each = toset(var.observability_alert_email_subscribers)

  topic_arn = aws_sns_topic.observability_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "notification_dlq_visible_messages" {
  alarm_name          = "${var.cluster_name}-notification-dlq-visible-messages"
  alarm_description   = "The notification dead-letter queue has messages that need inspection."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.sqs_dlq_visible_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.notification_dlq.name
  }
}

resource "aws_cloudwatch_metric_alarm" "notification_queue_oldest_message" {
  alarm_name          = "${var.cluster_name}-notification-queue-oldest-message"
  alarm_description   = "The notification queue has messages waiting longer than expected."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.sqs_oldest_message_age_alarm_seconds
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.notification.name
  }
}

resource "aws_cloudwatch_metric_alarm" "booking_confirmed_sns_failed" {
  alarm_name          = "${var.cluster_name}-booking-confirmed-sns-failed"
  alarm_description   = "SNS failed to deliver booking confirmed notifications."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    TopicName = aws_sns_topic.booking_confirmed.name
  }
}

resource "aws_cloudwatch_metric_alarm" "booking_cancelled_sns_failed" {
  alarm_name          = "${var.cluster_name}-booking-cancelled-sns-failed"
  alarm_description   = "SNS failed to deliver booking cancelled notifications."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    TopicName = aws_sns_topic.booking_cancelled.name
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttled_requests" {
  for_each = {
    auth_users    = aws_dynamodb_table.auth_users.name
    parking_slots = aws_dynamodb_table.parking_slots.name
    bookings      = aws_dynamodb_table.bookings.name
    payments      = aws_dynamodb_table.payments.name
    notifications = aws_dynamodb_table.notifications.name
  }

  alarm_name          = "${var.cluster_name}-${each.key}-dynamodb-throttled-requests"
  alarm_description   = "DynamoDB table ${each.value} has throttled requests."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.dynamodb_throttled_requests_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    TableName = each.value
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_system_errors" {
  for_each = {
    auth_users    = aws_dynamodb_table.auth_users.name
    parking_slots = aws_dynamodb_table.parking_slots.name
    bookings      = aws_dynamodb_table.bookings.name
    payments      = aws_dynamodb_table.payments.name
    notifications = aws_dynamodb_table.notifications.name
  }

  alarm_name          = "${var.cluster_name}-${each.key}-dynamodb-system-errors"
  alarm_description   = "DynamoDB table ${each.value} has system errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    TableName = each.value
  }
}

resource "aws_cloudwatch_event_rule" "eks_cluster_state_change" {
  name        = "${var.cluster_name}-cluster-state-change"
  description = "Capture EKS cluster state changes."

  event_pattern = jsonencode({
    source      = ["aws.eks"]
    detail-type = ["EKS Cluster State Change"]
    detail = {
      clusterName = [aws_eks_cluster.this.name]
    }
  })
}

resource "aws_cloudwatch_event_rule" "eks_node_group_state_change" {
  name        = "${var.cluster_name}-nodegroup-state-change"
  description = "Capture EKS managed node group state changes."

  event_pattern = jsonencode({
    source      = ["aws.eks"]
    detail-type = ["EKS Node Group State Change"]
    detail = {
      clusterName   = [aws_eks_cluster.this.name]
      nodegroupName = [aws_eks_node_group.this.node_group_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "eks_cluster_state_sns" {
  rule      = aws_cloudwatch_event_rule.eks_cluster_state_change.name
  target_id = "quickslot-eks-cluster-state-sns"
  arn       = aws_sns_topic.observability_alerts.arn
}

resource "aws_cloudwatch_event_target" "eks_node_group_state_sns" {
  rule      = aws_cloudwatch_event_rule.eks_node_group_state_change.name
  target_id = "quickslot-eks-nodegroup-state-sns"
  arn       = aws_sns_topic.observability_alerts.arn
}

resource "aws_cloudwatch_dashboard" "quickslot" {
  dashboard_name = "${var.cluster_name}-quickslot"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "SQS Notification Queue"
          region = var.aws_region
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.notification.name],
            [".", "ApproximateAgeOfOldestMessage", ".", "."],
            [".", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.notification_dlq.name]
          ]
          stat   = "Maximum"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "SNS Failed Notifications"
          region = var.aws_region
          metrics = [
            ["AWS/SNS", "NumberOfNotificationsFailed", "TopicName", aws_sns_topic.booking_confirmed.name],
            [".", ".", ".", aws_sns_topic.booking_cancelled.name]
          ]
          stat   = "Sum"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "DynamoDB Throttles"
          region = var.aws_region
          metrics = [
            ["AWS/DynamoDB", "ThrottledRequests", "TableName", aws_dynamodb_table.auth_users.name],
            [".", ".", ".", aws_dynamodb_table.parking_slots.name],
            [".", ".", ".", aws_dynamodb_table.bookings.name],
            [".", ".", ".", aws_dynamodb_table.payments.name],
            [".", ".", ".", aws_dynamodb_table.notifications.name]
          ]
          stat   = "Sum"
          period = 300
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_cloudwatch_agent_server" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
