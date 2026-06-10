resource "aws_secretsmanager_secret" "app_config" {
  name                    = var.name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name = var.name
  }
}

resource "aws_secretsmanager_secret_version" "app_config" {
  count = var.create_initial_secret_version ? 1 : 0

  secret_id     = aws_secretsmanager_secret.app_config.id
  secret_string = var.initial_secret_json != "" ? var.initial_secret_json : "{}"
}
