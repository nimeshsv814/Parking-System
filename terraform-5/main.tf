module "network" {
  source = "./modules/network"

  app_private_subnets = var.app_private_subnets
  db_private_subnets  = var.db_private_subnets
  public_subnets      = var.public_subnets
  vpc_cidr            = var.vpc_cidr
}

module "security" {
  source = "./modules/security"

  backend_from = var.backend_from
  backend_to   = var.backend_to
  db_port      = var.db_port
  http_port    = var.http_port
  ssh_port     = var.ssh_port
  vpc_id       = module.network.vpc_id
}

module "bastion" {
  source = "./modules/bastion"

  ami_id                    = var.ami_id
  bastion_security_group_id = module.security.bastion_security_group_id
  key_name                  = var.key_name
  public_subnet_1a_id       = module.network.public_subnet_ids["web-public-subnet-1a"]
}

module "load_balancers" {
  source = "./modules/load_balancers"

  app_private_subnet_ids         = values(module.network.app_private_subnet_ids)
  external_alb_security_group_id = module.security.external_alb_security_group_id
  internal_alb_security_group_id = module.security.internal_alb_security_group_id
  public_subnet_ids              = values(module.network.public_subnet_ids)
  vpc_id                         = module.network.vpc_id
}

locals {
  existing_app_config_secret_arn = trimspace(var.app_config_secret_arn)
  app_config_secret_arn          = local.existing_app_config_secret_arn != "" ? local.existing_app_config_secret_arn : (var.create_app_config_secret ? try(module.app_config_secret[0].secret_arn, "") : data.aws_secretsmanager_secret.app_config_existing[0].arn)
}

module "app_config_secret" {
  count = var.create_app_config_secret && local.existing_app_config_secret_arn == "" ? 1 : 0

  source = "./modules/secrets_manager"

  create_initial_secret_version = var.create_app_config_initial_secret_version && !var.manage_app_config_secret_value
  description                   = "Runtime secrets for Smart Parking application services"
  initial_secret_json           = var.app_config_initial_secret_json
  name                          = var.app_config_secret_name
  recovery_window_in_days       = var.app_config_secret_recovery_window_in_days
}

data "aws_secretsmanager_secret" "app_config_existing" {
  count = var.create_app_config_secret || local.existing_app_config_secret_arn != "" ? 0 : 1

  name = var.app_config_secret_name
}

resource "aws_secretsmanager_secret_version" "app_config_runtime" {
  count = var.manage_app_config_secret_value ? 1 : 0

  secret_id     = local.app_config_secret_arn
  secret_string = jsonencode(var.app_config_secret_values)
}

module "booking_sns_notifications" {
  count = var.enable_booking_sns_notifications ? 1 : 0

  source = "./modules/sns_notifications"

  booking_cancelled_email_subscribers = var.booking_cancelled_email_subscribers
  booking_cancelled_topic_name        = var.booking_cancelled_sns_topic_name
  booking_confirmed_email_subscribers = var.booking_confirmed_email_subscribers
  booking_confirmed_topic_name        = var.booking_confirmed_sns_topic_name
  enable_sqs_subscription             = var.enable_booking_sns_to_sqs_subscription
  notification_queue_arn              = var.sqs_notification_queue_arn
  notification_queue_url              = var.sqs_notification_queue_url
}

module "app_tier" {
  source = "./modules/app_tier"

  ami_id                          = var.ami_id
  app_desired_capacity            = var.app_desired_capacity
  app_config_secret_arn           = local.app_config_secret_arn
  app_instance_type               = var.app_instance_type
  app_max_size                    = var.app_max_size
  app_min_size                    = var.app_min_size
  app_private_subnet_ids          = values(module.network.app_private_subnet_ids)
  app_security_group_id           = module.security.app_security_group_id
  app_target_group_arn            = module.load_balancers.app_target_group_arn
  auth_service_image              = var.auth_service_image
  auth_users_table                = var.auth_users_table
  aws_region                      = var.aws_region
  booking_service_image           = var.booking_service_image
  booking_table                   = var.booking_table
  booking_cancelled_sns_topic_arn = var.enable_booking_sns_notifications ? module.booking_sns_notifications[0].booking_cancelled_topic_arn : ""
  booking_confirmed_sns_topic_arn = var.enable_booking_sns_notifications ? module.booking_sns_notifications[0].booking_confirmed_topic_arn : ""
  key_name                        = var.key_name
  notification_service_image      = var.notification_service_image
  notification_table              = var.notification_table
  parking_service_image           = var.parking_service_image
  parking_slots_table             = var.parking_slots_table
  payment_service_image           = var.payment_service_image
  payment_table                   = var.payment_table
  scheduler_service_image         = var.scheduler_service_image
  service_target_group_arns       = module.load_balancers.service_target_group_arns
  sqs_notification_queue_arn      = var.sqs_notification_queue_arn
  sqs_notification_queue_name     = var.sqs_notification_queue_name
  sqs_notification_queue_url      = var.sqs_notification_queue_url
}

module "web_tier" {
  source = "./modules/web_tier"

  ami_id                = var.ami_id
  frontend_image        = var.frontend_image
  internal_alb_dns_name = module.load_balancers.internal_alb_dns
  key_name              = var.key_name
  public_subnet_ids     = values(module.network.public_subnet_ids)
  web_desired_capacity  = var.web_desired_capacity
  web_instance_type     = var.web_instance_type
  web_max_size          = var.web_max_size
  web_min_size          = var.web_min_size
  web_security_group_id = module.security.web_security_group_id
  web_target_group_arn  = module.load_balancers.web_target_group_arn
}

locals {
  create_edge_hosted_zone          = var.enable_edge_stack && var.create_route53_hosted_zone
  edge_hosted_zone_id              = local.create_edge_hosted_zone ? aws_route53_zone.edge[0].zone_id : var.route53_hosted_zone_id
  existing_acm_certificate_arn     = trimspace(var.existing_acm_certificate_arn)
  create_acm_certificate           = var.enable_edge_stack && var.enable_acm && local.existing_acm_certificate_arn == ""
  cloudfront_custom_domain_enabled = var.enable_acm || local.existing_acm_certificate_arn != ""
  cloudfront_certificate_arn       = local.existing_acm_certificate_arn != "" ? local.existing_acm_certificate_arn : (var.enable_acm ? module.acm[0].certificate_arn : "")
  create_cloudfront_dns_record     = var.enable_edge_stack && var.create_cloudfront_route53_alias_record && var.app_domain_name != "" && local.edge_hosted_zone_id != ""
}

resource "aws_route53_zone" "edge" {
  count = local.create_edge_hosted_zone ? 1 : 0

  name = var.route53_zone_domain_name != "" ? var.route53_zone_domain_name : var.app_domain_name

  tags = {
    Name = "smart-parking-edge-zone"
  }
}

module "acm" {
  count = local.create_acm_certificate ? 1 : 0

  source = "./modules/acm"

  providers = {
    aws = aws.us_east_1
  }

  domain_name               = var.app_domain_name
  hosted_zone_id            = local.edge_hosted_zone_id
  subject_alternative_names = var.app_domain_subject_alternative_names
}

module "waf" {
  count = var.enable_edge_stack ? 1 : 0

  source = "./modules/waf"

  providers = {
    aws = aws.us_east_1
  }

  name       = "smart-parking-cloudfront-waf"
  rate_limit = var.waf_rate_limit
}

module "cdn" {
  count = var.enable_edge_stack ? 1 : 0

  source = "./modules/cdn"

  providers = {
    aws = aws.us_east_1
  }

  certificate_arn            = local.cloudfront_certificate_arn
  domain_name                = var.app_domain_name
  enable_custom_domain       = local.cloudfront_custom_domain_enabled
  origin_custom_header_name  = var.cloudfront_origin_custom_header_name
  origin_custom_header_value = var.cloudfront_origin_custom_header_value
  origin_domain_name         = module.load_balancers.external_alb_dns
  price_class                = var.cloudfront_price_class
  web_acl_arn                = var.enable_edge_stack ? module.waf[0].web_acl_arn : ""
}

module "route53" {
  count = local.create_cloudfront_dns_record ? 1 : 0

  source = "./modules/route53"

  cloudfront_domain_name    = module.cdn[0].domain_name
  cloudfront_hosted_zone_id = module.cdn[0].hosted_zone_id
  create_ipv6_record        = var.cloudfront_create_ipv6_record
  domain_name               = var.app_domain_name
  hosted_zone_id            = local.edge_hosted_zone_id
}
