variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  type = map(string)
  default = {
    web-public-subnet-1a = "10.0.1.0/24"
    web-public-subnet-1b = "10.0.2.0/24"
  }
}

variable "app_private_subnets" {
  type = map(string)
  default = {
    app-private-subnet-1a = "10.0.3.0/24"
    app-private-subnet-1b = "10.0.4.0/24"
  }
}

variable "db_private_subnets" {
  type = map(string)
  default = {
    data-private-subnet-1a = "10.0.5.0/24"
    data-private-subnet-1b = "10.0.6.0/24"
  }
}

variable "ssh_port" {
  type    = number
  default = 22
}

variable "http_port" {
  type    = number
  default = 80
}

variable "app_port" {
  type    = number
  default = 4000
}

variable "db_port" {
  type    = number
  default = 27017
}

variable "backend_from" {
  type    = number
  default = 4001
}

variable "backend_to" {
  type    = number
  default = 4006
}

variable "ami_id" {
  type    = string
  default = "ami-091138d0f0d41ff90"
}

variable "key_name" {
  type    = string
  default = "three-tier-arch"
}

variable "web_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "web_min_size" {
  type    = number
  default = 2
}

variable "web_max_size" {
  type    = number
  default = 4
}

variable "web_desired_capacity" {
  type    = number
  default = 2
}

variable "app_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "app_min_size" {
  type    = number
  default = 2
}

variable "app_max_size" {
  type    = number
  default = 4
}

variable "app_desired_capacity" {
  type    = number
  default = 2
}

variable "frontend_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-frontend:v1.1.1"
}

variable "auth_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-auth-service:latest"
}

variable "parking_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-parking-service:v1.1.0"
}

variable "booking_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-booking-service:latest"
}

variable "payment_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-payment-service:v1.1.1"
}

variable "scheduler_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-scheduler-service:latest"
}

variable "notification_service_image" {
  type    = string
  default = "docker.io/nimeshsv814/tf-notification-service:latest"
}

variable "mongodb_image" {
  type    = string
  default = "mongo:7"
}
