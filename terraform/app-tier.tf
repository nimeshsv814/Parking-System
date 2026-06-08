resource "aws_instance" "backend_server" {

  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name

  subnet_id = aws_subnet.app_private_subnets["app-private-subnet-1a"].id

  vpc_security_group_ids = [
    aws_security_group.app-sg.id
  ]

  user_data_replace_on_change = true

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

APP_REPO="https://github.com/nimeshsv814/Parking-System.git"
APP_DIR="/opt/smart-parking"
SERVICE_USER="smartparking"
DB_HOST="${aws_instance.database.private_ip}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl git nginx

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

id -u "$SERVICE_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$SERVICE_USER"

rm -rf "$APP_DIR"
git clone "$APP_REPO" "$APP_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"

cat <<EOT > "$APP_DIR/services/auth-service/.env"
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

cat <<EOT > "$APP_DIR/services/parking-service/.env"
PORT=4002
MONGO_URI=mongodb://$DB_HOST:27017/parkingdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
INTERNAL_API_KEY=smartparking_internal_key
EOT

cat <<EOT > "$APP_DIR/services/booking-service/.env"
PORT=4003
MONGO_URI=mongodb://$DB_HOST:27017/bookingdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
PARKING_SERVICE_URL=http://127.0.0.1:4002
NOTIFICATION_SERVICE_URL=http://127.0.0.1:4006
INTERNAL_API_KEY=smartparking_internal_key
BOOKING_HOLD_MINUTES=10
EOT

cat <<EOT > "$APP_DIR/services/payment-service/.env"
PORT=4004
MONGO_URI=mongodb://$DB_HOST:27017/paymentdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
BOOKING_SERVICE_URL=http://127.0.0.1:4003
NOTIFICATION_SERVICE_URL=http://127.0.0.1:4006
INTERNAL_API_KEY=smartparking_internal_key
RAZORPAY_KEY_ID=rzp_test_ShFFMxa9JkqmZu
RAZORPAY_KEY_SECRET=1I4sLVIvCMWSTUlM5lCZm71j
RAZORPAY_CURRENCY=INR
EOT

cat <<EOT > "$APP_DIR/services/scheduler-service/.env"
PORT=4005
BOOKING_SERVICE_URL=http://127.0.0.1:4003
INTERNAL_API_KEY=smartparking_internal_key
CRON_SCHEDULE=* * * * *
EOT

cat <<EOT > "$APP_DIR/services/notification-service/.env"
PORT=4006
MONGO_URI=mongodb://$DB_HOST:27017/notificationdb
JWT_SECRET=smartparking_super_secret
CORS_ORIGIN=*
INTERNAL_API_KEY=smartparking_internal_key
EOT

install_service_dependencies() {
  service_dir="$1"
  cd "$service_dir"
  if [ -f package-lock.json ]; then
    npm ci --omit=dev
  else
    npm install --omit=dev
  fi
  chown -R "$SERVICE_USER:$SERVICE_USER" "$service_dir"
}

install_service_dependencies "$APP_DIR/services/auth-service"
install_service_dependencies "$APP_DIR/services/parking-service"
install_service_dependencies "$APP_DIR/services/booking-service"
install_service_dependencies "$APP_DIR/services/payment-service"
install_service_dependencies "$APP_DIR/services/scheduler-service"
install_service_dependencies "$APP_DIR/services/notification-service"

create_node_service() {
  service_name="$1"
  service_dir="$2"

  cat <<SERVICE > "/etc/systemd/system/$service_name.service"
[Unit]
Description=Smart Parking $service_name
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$service_dir
EnvironmentFile=$service_dir/.env
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
}

create_node_service "auth-service" "$APP_DIR/services/auth-service"
create_node_service "parking-service" "$APP_DIR/services/parking-service"
create_node_service "booking-service" "$APP_DIR/services/booking-service"
create_node_service "payment-service" "$APP_DIR/services/payment-service"
create_node_service "scheduler-service" "$APP_DIR/services/scheduler-service"
create_node_service "notification-service" "$APP_DIR/services/notification-service"

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

systemctl daemon-reload
systemctl enable auth-service parking-service booking-service payment-service scheduler-service notification-service
systemctl restart auth-service parking-service notification-service
sleep 10
systemctl restart booking-service payment-service scheduler-service

sleep 10
{
  echo "Smart Parking app-tier deployment status"
  date -Is
  echo
  systemctl --no-pager --full status auth-service parking-service booking-service payment-service scheduler-service notification-service || true
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

  tags = {
    Name = "backend-server"
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

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web-server.id
  port             = 80
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

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.backend_server.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "service" {
  for_each = local.internal_services

  target_group_arn = aws_lb_target_group.service_tg[each.key].arn
  target_id        = aws_instance.backend_server.id
  port             = 80
}
