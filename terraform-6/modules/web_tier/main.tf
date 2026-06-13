resource "aws_iam_role" "web_ssm_role" {
  name = "quickslot-web-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "web_ssm_managed_instance_core" {
  role       = aws_iam_role.web_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web_ssm_profile" {
  name = "quickslot-web-ssm-profile"
  role = aws_iam_role.web_ssm_role.name
}

resource "aws_launch_template" "web" {
  name_prefix   = "smart-parking-web-"
  image_id      = var.ami_id
  instance_type = var.web_instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.web_ssm_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.web_security_group_id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
set -euxo pipefail

FRONTEND_IMAGE="${var.frontend_image}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y docker.io nginx snapd

systemctl enable snapd
systemctl start snapd

if ! systemctl list-unit-files | grep -q '^snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
  for attempt in 1 2 3 4 5 6; do
    snap wait system seed.loaded && break
    sleep 10
  done
  snap install amazon-ssm-agent --classic
fi

systemctl enable docker
systemctl start docker
systemctl enable nginx
systemctl start nginx
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

rm -f /etc/nginx/sites-enabled/default

cat <<'NGINXCONF' > /etc/nginx/conf.d/smart-parking-frontend.conf
server {
    listen 80 default_server;
    server_name _;

    location /auth/ {
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/auth/ {
        rewrite ^/api/auth/(.*)$ /auth/$1 break;
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /parking/ {
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/parking/ {
        rewrite ^/api/parking/(.*)$ /parking/$1 break;
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /booking/ {
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/booking/ {
        rewrite ^/api/booking/(.*)$ /booking/$1 break;
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /payment/ {
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/payment/ {
        rewrite ^/api/payment/(.*)$ /payment/$1 break;
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notification/ {
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/notification/ {
        rewrite ^/api/notification/(.*)$ /notification/$1 break;
        proxy_pass http://${var.internal_alb_dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /health {
        proxy_pass http://127.0.0.1:8080/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXCONF

nginx -t
systemctl reload nginx

cat <<'FRONTENDNGINX' > /opt/smart-parking-frontend-nginx.conf
server {
    listen 80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location = /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
FRONTENDNGINX

docker pull "$FRONTEND_IMAGE"
docker rm -f smart-parking-frontend || true
docker run -d \
  --name smart-parking-frontend \
  --restart unless-stopped \
  -p 127.0.0.1:8080:80 \
  -v /opt/smart-parking-frontend-nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  "$FRONTEND_IMAGE"

EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "web-server"
    }
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "smart-parking-web-asg"
  min_size                  = var.web_min_size
  max_size                  = var.web_max_size
  desired_capacity          = var.web_desired_capacity
  vpc_zone_identifier       = var.public_subnet_ids
  target_group_arns         = [var.web_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}
