variable "vpc_id" {
  type = string
}

variable "ssh_port" {
  type = number
}

variable "http_port" {
  type = number
}

variable "db_port" {
  type = number
}

variable "backend_from" {
  type = number
}

variable "backend_to" {
  type = number
}
