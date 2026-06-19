resource "aws_sns_topic" "observability_alerts" {
  name = var.observability_sns_topic_name

  tags = {
    Name        = var.observability_sns_topic_name
    Application = "smart-parking"
  }
}

resource "aws_cloudwatch_event_rule" "payment_invoice_pdf_created" {
  count = var.enable_invoice_eventbridge_notifications ? 1 : 0

  name        = "${var.cluster_name}-payment-invoice-pdf-created"
  description = "Detect QuickSlot payment invoice PDF creation in S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.payment_invoices.bucket]
      }
      object = {
        key = [{
          suffix = ".pdf"
        }]
      }
    }
  })
}

resource "aws_sns_topic_policy" "observability_alerts" {
  arn = aws_sns_topic.observability_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowCloudWatchAlarmsToPublish"
          Effect = "Allow"
          Principal = {
            Service = "cloudwatch.amazonaws.com"
          }
          Action   = "sns:Publish"
          Resource = aws_sns_topic.observability_alerts.arn
        }
      ],
      var.enable_invoice_eventbridge_notifications ? [
        {
          Sid    = "AllowEventBridgeInvoiceEventsToPublish"
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
      ] : [],
      [
        {
          Sid    = "AllowEventBridgeEksClusterStateToPublish"
          Effect = "Allow"
          Principal = {
            Service = "events.amazonaws.com"
          }
          Action   = "sns:Publish"
          Resource = aws_sns_topic.observability_alerts.arn
          Condition = {
            ArnEquals = {
              "aws:SourceArn" = aws_cloudwatch_event_rule.eks_cluster_state_change.arn
            }
          }
        },
        {
          Sid    = "AllowEventBridgeEksNodeGroupStateToPublish"
          Effect = "Allow"
          Principal = {
            Service = "events.amazonaws.com"
          }
          Action   = "sns:Publish"
          Resource = aws_sns_topic.observability_alerts.arn
          Condition = {
            ArnEquals = {
              "aws:SourceArn" = aws_cloudwatch_event_rule.eks_node_group_state_change.arn
            }
          }
        }
      ]
    )
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
