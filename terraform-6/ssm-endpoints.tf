locals {
  gateway_endpoint_services = toset([
    "s3",
    "dynamodb"
  ])

  interface_endpoint_services = toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
    "secretsmanager",
    "sqs",
    "sns",
    "kms",
    "logs"
  ])
}

resource "aws_security_group" "ssm_vpc_endpoints" {
  name        = "quickslot-ssm-vpc-endpoints-sg"
  description = "Allow app and web EC2 instances to reach AWS interface endpoints"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "HTTPS from app tier"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      module.security.app_security_group_id
    ]
  }

  ingress {
    description = "HTTPS from web tier"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      module.security.web_security_group_id
    ]
  }

  dynamic "ingress" {
    for_each = var.enable_agent_instance ? [1] : []

    content {
      description     = "HTTPS from DevOps Co-Pilot Agent"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = [aws_security_group.agent[0].id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "quickslot-ssm-vpc-endpoints-sg"
    Application = "smart-parking"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = local.interface_endpoint_services

  vpc_id              = module.network.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = values(module.network.app_private_subnet_ids)
  security_group_ids = [
    aws_security_group.ssm_vpc_endpoints.id
  ]

  tags = {
    Name        = "quickslot-${each.key}-endpoint"
    Application = "smart-parking"
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoint_services

  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    module.network.app_private_route_table_id,
    module.network.db_private_route_table_id
  ]

  tags = {
    Name        = "quickslot-${each.key}-gateway-endpoint"
    Application = "smart-parking"
  }
}
