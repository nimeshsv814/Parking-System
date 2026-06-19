data "archive_file" "invoice_emailer" {
  type        = "zip"
  source_file = "${path.module}/lambda/invoice_emailer.py"
  output_path = "${path.module}/lambda/invoice_emailer.zip"
}

resource "aws_ses_email_identity" "invoice_sender" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  email = var.invoice_email_sender
}

resource "aws_sqs_queue" "invoice_emailer_dlq" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  name                      = "quickslot-invoice-emailer-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Name        = "quickslot-invoice-emailer-dlq"
    Application = "smart-parking"
    Service     = "invoice-emailer"
  }
}

resource "aws_sqs_queue_policy" "invoice_emailer_dlq" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  queue_url = aws_sqs_queue.invoice_emailer_dlq[0].url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToSendFailedInvoiceEmailEvents"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.invoice_emailer_dlq[0].arn
      }
    ]
  })
}

resource "aws_iam_role" "invoice_emailer" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  name = "quickslot-invoice-emailer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "invoice_emailer_basic_execution" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  role       = aws_iam_role.invoice_emailer[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "invoice_emailer" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  name = "quickslot-invoice-emailer-policy"
  role = aws_iam_role.invoice_emailer[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging"
        ]
        Resource = "${module.storage.payment_invoice_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = module.storage.payment_invoice_kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem"
        ]
        Resource = [
          aws_dynamodb_table.auth_users.arn,
          aws_dynamodb_table.bookings.arn,
          aws_dynamodb_table.payments.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.invoice_emailer_dlq[0].arn
      }
    ]
  })
}

resource "aws_lambda_function" "invoice_emailer" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  function_name    = "quickslot-invoice-emailer"
  role             = aws_iam_role.invoice_emailer[0].arn
  runtime          = "python3.12"
  handler          = "invoice_emailer.handler"
  filename         = data.archive_file.invoice_emailer.output_path
  source_code_hash = data.archive_file.invoice_emailer.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      AUTH_USERS_TABLE   = aws_dynamodb_table.auth_users.name
      BOOKING_TABLE      = aws_dynamodb_table.bookings.name
      PAYMENT_TABLE      = aws_dynamodb_table.payments.name
      SENDER_EMAIL       = var.invoice_email_sender
      URL_EXPIRY_SECONDS = tostring(var.invoice_presigned_url_expiry_seconds)
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.invoice_emailer_dlq[0].arn
  }

  tags = {
    Name        = "quickslot-invoice-emailer"
    Application = "smart-parking"
    Service     = "invoice-emailer"
  }

  depends_on = [
    aws_iam_role_policy_attachment.invoice_emailer_basic_execution,
    aws_iam_role_policy.invoice_emailer
  ]
}

resource "aws_cloudwatch_event_rule" "payment_invoice_email_created" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  name        = "quickslot-payment-invoice-email-created"
  description = "Send invoice email when a payment invoice PDF is created in S3."

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [module.storage.payment_invoice_bucket_name]
      }
      object = {
        key = [{
          wildcard = "payment-invoices/*.pdf"
        }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "payment_invoice_email_lambda" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.payment_invoice_email_created[0].name
  target_id = "quickslot-payment-invoice-emailer"
  arn       = aws_lambda_function.invoice_emailer[0].arn

  dead_letter_config {
    arn = aws_sqs_queue.invoice_emailer_dlq[0].arn
  }
}

resource "aws_lambda_permission" "allow_eventbridge_invoice_emailer" {
  count = var.enable_invoice_email_notifications ? 1 : 0

  statement_id  = "AllowEventBridgeInvoiceEmailer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.invoice_emailer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.payment_invoice_email_created[0].arn
}
