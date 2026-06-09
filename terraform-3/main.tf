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

module "app_tier" {
  source = "./modules/app_tier"

  ami_id                      = var.ami_id
  app_desired_capacity        = var.app_desired_capacity
  app_instance_type           = var.app_instance_type
  app_max_size                = var.app_max_size
  app_min_size                = var.app_min_size
  app_private_subnet_ids      = values(module.network.app_private_subnet_ids)
  app_security_group_id       = module.security.app_security_group_id
  app_target_group_arn        = module.load_balancers.app_target_group_arn
  auth_service_image          = var.auth_service_image
  auth_users_table            = var.auth_users_table
  aws_region                  = var.aws_region
  booking_service_image       = var.booking_service_image
  booking_table               = var.booking_table
  key_name                    = var.key_name
  notification_service_image  = var.notification_service_image
  notification_table          = var.notification_table
  parking_service_image       = var.parking_service_image
  parking_slots_table         = var.parking_slots_table
  payment_service_image       = var.payment_service_image
  payment_table               = var.payment_table
  scheduler_service_image     = var.scheduler_service_image
  service_target_group_arns   = module.load_balancers.service_target_group_arns
  sqs_notification_queue_arn  = var.sqs_notification_queue_arn
  sqs_notification_queue_name = var.sqs_notification_queue_name
  sqs_notification_queue_url  = var.sqs_notification_queue_url
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
