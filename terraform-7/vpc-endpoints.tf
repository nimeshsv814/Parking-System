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

resource "aws_iam_role_policy_attachment" "node_ssm_managed_instance_core" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.cluster_name}-vpc-endpoints-sg"
  description = "Allow private EKS nodes to reach AWS interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from private EKS subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-vpc-endpoints-sg"
    Application = "smart-parking"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name        = "${var.cluster_name}-${each.key}-endpoint"
    Application = "smart-parking"
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoint_services

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name        = "${var.cluster_name}-${each.key}-gateway-endpoint"
    Application = "smart-parking"
  }
}
