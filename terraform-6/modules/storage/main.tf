data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  invoice_bucket_name = var.bucket_name != "" ? var.bucket_name : "smart-parking-payment-invoices-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  common_tags = merge(
    {
      Application = "smart-parking"
      Service     = "payment-service"
    },
    var.tags
  )
}

resource "aws_kms_key" "payment_invoices" {
  description             = "KMS key for Smart Parking payment invoice objects"
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "smart-parking-payment-invoices"
  })
}

resource "aws_kms_alias" "payment_invoices" {
  name          = "alias/smart-parking-payment-invoices"
  target_key_id = aws_kms_key.payment_invoices.key_id
}

resource "aws_s3_bucket" "payment_invoices" {
  bucket        = local.invoice_bucket_name
  force_destroy = var.force_destroy

  tags = merge(local.common_tags, {
    Name = local.invoice_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "payment_invoices" {
  bucket = aws_s3_bucket.payment_invoices.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "payment_invoices" {
  bucket = aws_s3_bucket.payment_invoices.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "payment_invoices" {
  bucket = aws_s3_bucket.payment_invoices.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.payment_invoices.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "payment_invoices" {
  bucket = aws_s3_bucket.payment_invoices.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "payment_invoices" {
  bucket = aws_s3_bucket.payment_invoices.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.payment_invoices.arn,
          "${aws_s3_bucket.payment_invoices.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
