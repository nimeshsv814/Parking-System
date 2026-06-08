resource "aws_instance" "web-server" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name

  subnet_id = aws_subnet.public_subnets["web-public-subnet-1a"].id

  vpc_security_group_ids = [
    aws_security_group.web-sg.id
  ]

  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

APP_REPO="https://github.com/nimeshsv814/Parking-System.git"
APP_DIR="/opt/smart-parking"
WEB_ROOT="/var/www/smart-parking"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl git nginx

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

rm -rf "$APP_DIR"
git clone "$APP_REPO" "$APP_DIR"

cat <<ENVFILE > "$APP_DIR/frontend/.env"
VITE_AUTH_SERVICE_URL=/api/auth
VITE_PARKING_SERVICE_URL=/api/parking
VITE_BOOKING_SERVICE_URL=/api/booking
VITE_PAYMENT_SERVICE_URL=/api/payment
VITE_NOTIFICATION_SERVICE_URL=/api/notification
ENVFILE

cd "$APP_DIR/frontend"
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi
npm run build

rm -rf "$WEB_ROOT"
mkdir -p "$WEB_ROOT"
cp -R "$APP_DIR/frontend/dist/." "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"

rm -f /etc/nginx/sites-enabled/default

cat <<'NGINXCONF' > /etc/nginx/conf.d/smart-parking-frontend.conf
server {
    listen 80 default_server;
    server_name _;

    root /var/www/smart-parking;
    index index.html;

    location /api/auth/ {
        rewrite ^/api/auth/(.*)$ /auth/$1 break;
        proxy_pass http://${aws_lb.internal_alb.dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/parking/ {
        rewrite ^/api/parking/(.*)$ /parking/$1 break;
        proxy_pass http://${aws_lb.internal_alb.dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/booking/ {
        rewrite ^/api/booking/(.*)$ /booking/$1 break;
        proxy_pass http://${aws_lb.internal_alb.dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/payment/ {
        rewrite ^/api/payment/(.*)$ /payment/$1 break;
        proxy_pass http://${aws_lb.internal_alb.dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/notification/ {
        rewrite ^/api/notification/(.*)$ /notification/$1 break;
        proxy_pass http://${aws_lb.internal_alb.dns_name};
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

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINXCONF

nginx -t
systemctl enable nginx
systemctl restart nginx

EOF

  tags = {
    Name = "Web-server"
  }
}
