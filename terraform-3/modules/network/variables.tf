variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = map(string)
}

variable "app_private_subnets" {
  type = map(string)
}

variable "db_private_subnets" {
  type = map(string)
}
