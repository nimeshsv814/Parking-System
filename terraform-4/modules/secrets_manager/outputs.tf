output "secret_arn" {
  value = aws_secretsmanager_secret.app_config.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.app_config.name
}
