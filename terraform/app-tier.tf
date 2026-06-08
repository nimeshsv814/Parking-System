resource "aws_launch_template" "app" {
  name_prefix   = "smart-parking-app-"
  image_id      = var.ami_id
  instance_type = var.app_instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app-sg.id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
set -euxo pipefail

DB_HOST="${aws_instance.database.private_ip}"
AUTH_SERVICE_IMAGE="${var.auth_service_image}"
PARKING_SERVICE_IMAGE="${var.parking_service_image}"
BOOKING_SERVICE_IMAGE="${var.booking_service_image}"
PAYMENT_SERVICE_IMAGE="${var.payment_service_image}"
SCHEDULER_SERVICE_IMAGE="${var.scheduler_service_image}"
NOTIFICATION_SERVICE_IMAGE="${var.notification_service_image}"
ENV_DIR="/opt/smart-parking-env"
APP_NETWORK="smart-parking-app"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y docker.io nginx

systemctl enable docker
systemctl start docker
systemctl enable nginx
systemctl start nginx

mkdir -p "$ENV_DIR"
docker network create "$APP_NETWORK" || true

cat <<EOT > "$ENV_DIR/auth-service.env"
PORT=4001
MONGO_URI=mongodb://$DB_HOST:27017/authdb
JWT_SECRET=smartparking_super_secret
JWT_EXPIRES_IN=7d
CORS_ORIGIN=*
SEED_ADMIN_EMAIL=admin@parking.com
SEED_ADMIN_PASSWORD=Admin@123
SEED_USER_EMAIL=user@parking.com
SEED_USER_PASSWORD=User@123
EOT

cat <<EOT > "$ENV_DIR/parking-service.env"
PORT=4002
MONGO_URI=mongodb://$DB_HOST:27017/parkingdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
INTERNAL_API_KEY=smartparking_internal_key
EOT

cat <<EOT > "$ENV_DIR/booking-service.env"
PORT=4003
MONGO_URI=mongodb://$DB_HOST:27017/bookingdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
PARKING_SERVICE_URL=http://parking-service:4002
NOTIFICATION_SERVICE_URL=http://notification-service:4006
INTERNAL_API_KEY=smartparking_internal_key
BOOKING_HOLD_MINUTES=10
EOT

cat <<EOT > "$ENV_DIR/payment-service.env"
PORT=4004
MONGO_URI=mongodb://$DB_HOST:27017/paymentdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
BOOKING_SERVICE_URL=http://booking-service:4003
NOTIFICATION_SERVICE_URL=http://notification-service:4006
INTERNAL_API_KEY=smartparking_internal_key
RAZORPAY_KEY_ID=rzp_test_ShFFMxa9JkqmZu
RAZORPAY_KEY_SECRET=1I4sLVIvCMWSTUlM5lCZm71j
RAZORPAY_CURRENCY=INR
EOT

cat <<EOT > "$ENV_DIR/scheduler-service.env"
PORT=4005
BOOKING_SERVICE_URL=http://booking-service:4003
INTERNAL_API_KEY=smartparking_internal_key
CRON_SCHEDULE=* * * * *
EOT

cat <<EOT > "$ENV_DIR/notification-service.env"
PORT=4006
MONGO_URI=mongodb://$DB_HOST:27017/notificationdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
INTERNAL_API_KEY=smartparking_internal_key
EOT

run_service_container() {
  container_name="$1"
  image="$2"
  env_file="$3"
  host_port="$4"
  container_port="$5"

  docker pull "$image"
  docker rm -f "$container_name" || true
  docker run -d \
    --name "$container_name" \
    --restart unless-stopped \
    --network "$APP_NETWORK" \
    --env-file "$env_file" \
    -p "127.0.0.1:$host_port:$container_port" \
    "$image"
}

run_service_container "auth-service" "$AUTH_SERVICE_IMAGE" "$ENV_DIR/auth-service.env" 4001 4001
run_service_container "parking-service" "$PARKING_SERVICE_IMAGE" "$ENV_DIR/parking-service.env" 4002 4002
run_service_container "notification-service" "$NOTIFICATION_SERVICE_IMAGE" "$ENV_DIR/notification-service.env" 4006 4006
run_service_container "booking-service" "$BOOKING_SERVICE_IMAGE" "$ENV_DIR/booking-service.env" 4003 4003
run_service_container "payment-service" "$PAYMENT_SERVICE_IMAGE" "$ENV_DIR/payment-service.env" 4004 4004
run_service_container "scheduler-service" "$SCHEDULER_SERVICE_IMAGE" "$ENV_DIR/scheduler-service.env" 4005 4005

rm -f /etc/nginx/sites-enabled/default

cat <<'NGINXCONF' > /etc/nginx/conf.d/smart-parking-backend.conf
server {
    listen 80 default_server;
    server_name _;

    location /auth/ {
        rewrite ^/auth/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4001/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/auth/ {
        rewrite ^/api/auth/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /parking/ {
        rewrite ^/parking/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4002/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/parking/ {
        rewrite ^/api/parking/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4002;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /booking/ {
        rewrite ^/booking/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4003/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/booking/ {
        rewrite ^/api/booking/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4003;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /payment/ {
        rewrite ^/payment/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4004/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/payment/ {
        rewrite ^/api/payment/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4004;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notification/ {
        rewrite ^/notification/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4006/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/notification/ {
        rewrite ^/api/notification/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:4006;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
NGINXCONF

nginx -t
systemctl enable nginx
systemctl restart nginx

sleep 10
{
  echo "Smart Parking app-tier deployment status"
  date -Is
  echo
  docker ps --filter "network=$APP_NETWORK"
  echo
  docker logs --tail 50 auth-service || true
  docker logs --tail 50 parking-service || true
  docker logs --tail 50 booking-service || true
  docker logs --tail 50 payment-service || true
  docker logs --tail 50 scheduler-service || true
  docker logs --tail 50 notification-service || true
  echo
  echo "Local route health checks:"
  curl -fsS http://127.0.0.1/auth/health || true
  echo
  curl -fsS http://127.0.0.1/parking/health || true
  echo
  curl -fsS http://127.0.0.1/booking/health || true
  echo
  curl -fsS http://127.0.0.1/payment/health || true
  echo
  curl -fsS http://127.0.0.1/notification/health || true
  echo
} > /opt/smart-parking-deploy-status.txt

EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "backend-server"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "smart-parking-app-asg"
  min_size            = var.app_min_size
  max_size            = var.app_max_size
  desired_capacity    = var.app_desired_capacity
  vpc_zone_identifier = [for s in aws_subnet.app_private_subnets : s.id]
  target_group_arns = concat(
    [aws_lb_target_group.app_tg.arn],
    [for tg in aws_lb_target_group.service_tg : tg.arn]
  )
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "backend-server"
    propagate_at_launch = true
  }
}

resource "aws_lb" "external_alb" {
  name               = "external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.externalALB-sg.id]
  subnets            = [for s in aws_subnet.public_subnets : s.id]

  tags = {
    Name = "external-alb"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name        = "tg-web"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

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
  security_groups    = [aws_security_group.internalALB-sg.id]
  subnets            = [for s in aws_subnet.app_private_subnets : s.id]

  tags = {
    Name = "smart-parking-internal-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "tg-app-services"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

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
  vpc_id      = aws_vpc.main.id

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
