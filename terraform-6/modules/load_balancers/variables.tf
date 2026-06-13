variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_private_subnet_ids" {
  type = list(string)
}

variable "external_alb_security_group_id" {
  type = string
}

variable "internal_alb_security_group_id" {
  type = string
}
