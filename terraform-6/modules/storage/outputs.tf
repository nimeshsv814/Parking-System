output "payment_invoice_bucket_name" {
  description = "S3 bucket name for payment invoices"
  value       = aws_s3_bucket.payment_invoices.bucket
}

output "payment_invoice_bucket_arn" {
  description = "S3 bucket ARN for payment invoices"
  value       = aws_s3_bucket.payment_invoices.arn
}

output "payment_invoice_kms_key_arn" {
  description = "KMS key ARN used to encrypt payment invoices"
  value       = aws_kms_key.payment_invoices.arn
}

output "payment_invoice_kms_key_id" {
  description = "KMS key ID used to encrypt payment invoices"
  value       = aws_kms_key.payment_invoices.key_id
}
