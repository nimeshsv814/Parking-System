locals {
  app_log_group_names = {
    auth         = "/quickslot/app/auth-service"
    parking      = "/quickslot/app/parking-service"
    booking      = "/quickslot/app/booking-service"
    payment      = "/quickslot/app/payment-service"
    scheduler    = "/quickslot/app/scheduler-service"
    notification = "/quickslot/app/notification-service"
  }

  app_log_group_arns = {
    for service, log_group in aws_cloudwatch_log_group.app_services : service => log_group.arn
  }

  observability_alarm_actions = length(var.observability_alert_email_subscribers) > 0 ? [aws_sns_topic.observability_alerts.arn] : []
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

resource "aws_sns_topic" "observability_alerts" {
  name         = "quickslot-observability-alerts"
  display_name = "QuickSlot Observability Alerts"

  tags = {
    Name        = "quickslot-observability-alerts"
    Application = "smart-parking"
  }
}

resource "aws_sns_topic_subscription" "observability_alert_email" {
  for_each = toset(var.observability_alert_email_subscribers)

  topic_arn = aws_sns_topic.observability_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "external_alb_target_5xx" {
  alarm_name          = "quickslot-external-alb-target-5xx"
  alarm_description   = "External ALB target 5XX responses are above the configured threshold."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    LoadBalancer = module.load_balancers.external_alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "app_target_unhealthy" {
  alarm_name          = "quickslot-app-targets-unhealthy"
  alarm_description   = "The internal app target group has unhealthy targets."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    LoadBalancer = module.load_balancers.internal_alb_arn_suffix
    TargetGroup  = module.load_balancers.app_target_group_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "payment_target_unhealthy" {
  alarm_name          = "quickslot-payment-targets-unhealthy"
  alarm_description   = "The payment service target group has unhealthy targets."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    LoadBalancer = module.load_balancers.internal_alb_arn_suffix
    TargetGroup  = module.load_balancers.service_target_group_arn_suffixes["payment"]
  }
}

resource "aws_cloudwatch_metric_alarm" "notification_dlq_visible_messages" {
  count = var.create_sqs_notification_queue ? 1 : 0

  alarm_name          = "quickslot-notification-dlq-visible-messages"
  alarm_description   = "The notification dead-letter queue has messages that need inspection."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.notification_dlq[0].name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_asg_cpu_high" {
  alarm_name          = "quickslot-app-asg-cpu-high"
  alarm_description   = "Average CPU utilization for the app Auto Scaling Group is high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.app_cpu_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.observability_alarm_actions
  ok_actions          = local.observability_alarm_actions

  dimensions = {
    AutoScalingGroupName = module.app_tier.autoscaling_group_name
  }
}

resource "aws_s3_bucket_notification" "payment_invoices_eventbridge" {
  count = var.enable_invoice_eventbridge_notifications ? 1 : 0

  bucket      = module.storage.payment_invoice_bucket_name
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "payment_invoice_pdf_created" {
  count = var.enable_invoice_eventbridge_notifications ? 1 : 0

  name        = "quickslot-payment-invoice-pdf-created"
  description = "Matches newly created PDF payment invoices in the invoice S3 bucket."

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [module.storage.payment_invoice_bucket_name]
      }
      object = {
        key = [
          {
            wildcard = "payment-invoices/*.pdf"
          }
        ]
      }
    }
  })
}

resource "aws_sns_topic_policy" "allow_eventbridge_invoice_events" {
  count = var.enable_invoice_eventbridge_notifications ? 1 : 0

  arn = aws_sns_topic.observability_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeInvoiceEvents"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.observability_alerts.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.payment_invoice_pdf_created[0].arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "payment_invoice_pdf_sns" {
  count = var.enable_invoice_eventbridge_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.payment_invoice_pdf_created[0].name
  target_id = "quickslot-payment-invoice-pdf-sns"
  arn       = aws_sns_topic.observability_alerts.arn

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
      time   = "$.time"
    }

    input_template = "\"QuickSlot payment invoice PDF created at <time>: s3://<bucket>/<key>\""
  }
}
