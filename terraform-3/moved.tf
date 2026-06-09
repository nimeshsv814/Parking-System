moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_internet_gateway.igw
  to   = module.network.aws_internet_gateway.igw
}

moved {
  from = aws_subnet.public_subnets
  to   = module.network.aws_subnet.public_subnets
}

moved {
  from = aws_subnet.app_private_subnets
  to   = module.network.aws_subnet.app_private_subnets
}

moved {
  from = aws_subnet.db_private_subnets
  to   = module.network.aws_subnet.db_private_subnets
}

moved {
  from = aws_eip.nat
  to   = module.network.aws_eip.nat
}

moved {
  from = aws_nat_gateway.nat
  to   = module.network.aws_nat_gateway.nat
}

moved {
  from = aws_route_table.public
  to   = module.network.aws_route_table.public
}

moved {
  from = aws_route_table.app-private
  to   = module.network.aws_route_table.app-private
}

moved {
  from = aws_route_table_association.pub
  to   = module.network.aws_route_table_association.pub
}

moved {
  from = aws_route_table_association.pri
  to   = module.network.aws_route_table_association.pri
}

moved {
  from = aws_route_table.db-private
  to   = module.network.aws_route_table.db-private
}

moved {
  from = aws_route_table_association.db-pri
  to   = module.network.aws_route_table_association.db-pri
}

moved {
  from = aws_security_group.bastion-host-sg
  to   = module.security.aws_security_group.bastion-host-sg
}

moved {
  from = aws_security_group.externalALB-sg
  to   = module.security.aws_security_group.externalALB-sg
}

moved {
  from = aws_security_group.web-sg
  to   = module.security.aws_security_group.web-sg
}

moved {
  from = aws_security_group.internalALB-sg
  to   = module.security.aws_security_group.internalALB-sg
}

moved {
  from = aws_security_group.app-sg
  to   = module.security.aws_security_group.app-sg
}

moved {
  from = aws_security_group.db-sg
  to   = module.security.aws_security_group.db-sg
}

moved {
  from = aws_instance.bastion-host
  to   = module.bastion.aws_instance.bastion-host
}

moved {
  from = aws_lb.external_alb
  to   = module.load_balancers.aws_lb.external_alb
}

moved {
  from = aws_lb.internal_alb
  to   = module.load_balancers.aws_lb.internal_alb
}

moved {
  from = aws_lb_target_group.web_tg
  to   = module.load_balancers.aws_lb_target_group.web_tg
}

moved {
  from = aws_lb_target_group.app_tg
  to   = module.load_balancers.aws_lb_target_group.app_tg
}

moved {
  from = aws_lb_target_group.service_tg
  to   = module.load_balancers.aws_lb_target_group.service_tg
}

moved {
  from = aws_lb_listener.external_http_listener
  to   = module.load_balancers.aws_lb_listener.external_http_listener
}

moved {
  from = aws_lb_listener.internal_http_listener
  to   = module.load_balancers.aws_lb_listener.internal_http_listener
}

moved {
  from = aws_lb_listener_rule.service_routes
  to   = module.load_balancers.aws_lb_listener_rule.service_routes
}

moved {
  from = aws_iam_role.app_dynamodb_role
  to   = module.app_tier.aws_iam_role.app_dynamodb_role
}

moved {
  from = aws_iam_role_policy.app_dynamodb_policy
  to   = module.app_tier.aws_iam_role_policy.app_dynamodb_policy
}

moved {
  from = aws_iam_instance_profile.app_dynamodb_profile
  to   = module.app_tier.aws_iam_instance_profile.app_dynamodb_profile
}

moved {
  from = aws_launch_template.app
  to   = module.app_tier.aws_launch_template.app
}

moved {
  from = aws_autoscaling_group.app
  to   = module.app_tier.aws_autoscaling_group.app
}

moved {
  from = aws_launch_template.web
  to   = module.web_tier.aws_launch_template.web
}

moved {
  from = aws_autoscaling_group.web
  to   = module.web_tier.aws_autoscaling_group.web
}
