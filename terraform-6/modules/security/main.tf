#Security group for Bastion host
resource "aws_security_group" "bastion-host-sg" {
  name        = "Bastion Host-SG"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Bastion-SG"
  }
}

#Security group for External loadbalancer
resource "aws_security_group" "externalALB-sg" {
  name        = "externalALB-SG"
  description = "Security group for external LB"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ExternalALB-SG"
  }
}

#Security group for Web-SG
resource "aws_security_group" "web-sg" {
  name        = "Web-SG"
  description = "Security group for Web tier"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = var.http_port
    to_port         = var.http_port
    protocol        = "tcp"
    security_groups = [aws_security_group.externalALB-sg.id]
  }
  ingress {
    from_port       = var.ssh_port
    to_port         = var.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-host-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Web-SG"
  }
}

#Security group for Internal loadbalancer
resource "aws_security_group" "internalALB-sg" {
  name        = "internalALB-SG"
  description = "Security group for internal LB"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = var.http_port
    to_port         = var.http_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "InternalALB-SG"
  }
}

#Security group for App Tier
resource "aws_security_group" "app-sg" {
  name        = "App-SG"
  description = "Security group for App tier"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = var.http_port
    to_port         = var.http_port
    protocol        = "tcp"
    security_groups = [aws_security_group.internalALB-sg.id]
  }
  ingress {
    from_port       = var.backend_from
    to_port         = var.backend_to
    protocol        = "tcp"
    security_groups = [aws_security_group.internalALB-sg.id]
  }
  ingress {
    from_port       = var.ssh_port
    to_port         = var.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-host-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "App-SG"
  }
}

resource "aws_security_group" "db-sg" {
  name        = "DB-SG"
  description = "Security group for DB tier"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app-sg.id]
  }
  ingress {
    from_port       = var.ssh_port
    to_port         = var.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-host-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "DB-SG"
  }
}
