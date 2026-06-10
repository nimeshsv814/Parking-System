variable "domain_name" {
  type = string
}

variable "enable_custom_domain" {
  type = bool
}

variable "origin_domain_name" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "web_acl_arn" {
  type = string
}

variable "price_class" {
  type = string
}

variable "origin_custom_header_name" {
  type = string
}

variable "origin_custom_header_value" {
  type = string
}
