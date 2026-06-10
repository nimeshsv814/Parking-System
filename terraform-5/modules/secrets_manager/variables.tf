variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "recovery_window_in_days" {
  type = number
}

variable "create_initial_secret_version" {
  type = bool
}

variable "initial_secret_json" {
  type      = string
  sensitive = true
}
