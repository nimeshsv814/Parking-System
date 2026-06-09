variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "web_instance_type" {
  type = string
}

variable "web_min_size" {
  type = number
}

variable "web_max_size" {
  type = number
}

variable "web_desired_capacity" {
  type = number
}

variable "frontend_image" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "web_security_group_id" {
  type = string
}

variable "web_target_group_arn" {
  type = string
}

variable "internal_alb_dns_name" {
  type = string
}
