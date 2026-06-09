# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "three-tier-vpc"
  }
}

#Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "my-igw"
  }
}

#Public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key == "web-public-subnet-1a" ? "us-east-1a" : "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = each.key
  }
}

#Private subnet for App-Tier
resource "aws_subnet" "app_private_subnets" {
  for_each          = var.app_private_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key == "app-private-subnet-1a" ? "us-east-1a" : "us-east-1b"
  tags = {
    Name = each.key
  }
}

#Private subnet for DB-Tier
resource "aws_subnet" "db_private_subnets" {
  for_each          = var.db_private_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key == "data-private-subnet-1a" ? "us-east-1a" : "us-east-1b"
  tags = {
    Name = each.key
  }
}

#Elastic IP for NAT
resource "aws_eip" "nat" {
  domain = "vpc"
}

#NAT gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnets["web-public-subnet-1a"].id
  tags = {
    Name = "NAT"
  }
}

#Public Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public-RT"
  }
}

#Subnet association for public route table
resource "aws_route_table_association" "pub" {
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

#Private route table for App Tier
resource "aws_route_table" "app-private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "App-Private-RT"
  }
}

#Subnet association for App private route table
resource "aws_route_table_association" "pri" {
  for_each       = aws_subnet.app_private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app-private.id
}

#Private route table for DB tier
resource "aws_route_table" "db-private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "DB-Private-RT"
  }
}

#Subnet association for DB private route table
resource "aws_route_table_association" "db-pri" {
  for_each       = aws_subnet.db_private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.db-private.id
}
