resource "aws_lb" "external_alb" {
  name               = "external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.external_alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "external-alb"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name        = "tg-web"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
  }
}

resource "aws_lb_listener" "external_http_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_lb" "internal_alb" {
  name               = "smart-parking-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.internal_alb_security_group_id]
  subnets            = var.app_private_subnet_ids

  tags = {
    Name = "smart-parking-internal-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "tg-app-services"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
  }
}

locals {
  internal_services = {
    auth = {
      priority    = 10
      paths       = ["/auth/*", "/api/auth/*"]
      health_path = "/auth/health"
    }
    parking = {
      priority    = 20
      paths       = ["/parking/*", "/api/parking/*"]
      health_path = "/parking/health"
    }
    booking = {
      priority    = 30
      paths       = ["/booking/*", "/api/booking/*"]
      health_path = "/booking/health"
    }
    payment = {
      priority    = 40
      paths       = ["/payment/*", "/api/payment/*"]
      health_path = "/payment/health"
    }
    notification = {
      priority    = 50
      paths       = ["/notification/*", "/api/notification/*"]
      health_path = "/notification/health"
    }
  }
}

resource "aws_lb_target_group" "service_tg" {
  for_each = local.internal_services

  name        = "tg-${each.key}-svc"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = each.value.health_path
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
}

resource "aws_lb_listener" "internal_http_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_listener_rule" "service_routes" {
  for_each = local.internal_services

  listener_arn = aws_lb_listener.internal_http_listener.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.paths
    }
  }
}
