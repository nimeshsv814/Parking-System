variable "bucket_name" {
  type        = string
  description = "Optional globally unique S3 bucket name for payment invoices. When blank, a name is generated from the AWS account and region."
  default     = ""
}

variable "force_destroy" {
  type        = bool
  description = "Allow Terraform to delete the invoice bucket even when it contains objects. Keep false for production."
  default     = false
}

variable "kms_key_deletion_window_in_days" {
  type        = number
  description = "Waiting period before deleting the payment invoice KMS key."
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to storage resources."
  default     = {}
}
