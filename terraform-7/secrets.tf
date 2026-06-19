locals {
  app_config_secret_values = {
    JWT_SECRET          = var.jwt_secret
    INTERNAL_API_KEY    = var.internal_api_key
    SEED_ADMIN_EMAIL    = var.seed_admin_email
    SEED_ADMIN_PASSWORD = var.seed_admin_password
    SEED_USER_EMAIL     = var.seed_user_email
    SEED_USER_PASSWORD  = var.seed_user_password
    RAZORPAY_KEY_ID     = var.razorpay_key_id
    RAZORPAY_KEY_SECRET = var.razorpay_key_secret
    RAZORPAY_CURRENCY   = var.razorpay_currency
    GEMINI_API_KEY      = var.gemini_api_key
    GEMINI_MODEL        = var.gemini_model
  }
}

resource "aws_secretsmanager_secret" "app_config" {
  name                    = var.app_config_secret_name
  description             = "Runtime secrets for QuickSlot EKS application services"
  recovery_window_in_days = var.app_config_secret_recovery_window_in_days

  tags = {
    Name        = var.app_config_secret_name
    Application = "smart-parking"
  }
}

resource "aws_secretsmanager_secret_version" "app_config" {
  count = var.manage_app_config_secret_value ? 1 : 0

  secret_id     = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode(local.app_config_secret_values)
}
