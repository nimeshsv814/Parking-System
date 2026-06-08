resource "aws_launch_template" "web" {
  name_prefix   = "smart-parking-web-"
  image_id      = var.ami_id
  instance_type = var.web_instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web-sg.id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
set -euxo pipefail

FRONTEND_IMAGE="${var.frontend_image}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y docker.io nginx

systemctl enable docker
systemctl start docker
systemctl enable nginx
systemctl start nginx

rm -f /etc/nginx/sites-enabled/default

cat <<'NGINXCONF' > /etc/nginx/conf.d/smart-parking-frontend.conf
server {
    listen 80 default_server;
    server_name _;

    location /auth/ {
        proxy_pass http://${aws_lb.internal_alb.dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/auth/ {
        rewrite ^/api/auth/(.*)$ /auth/$1 break;
        proxy_pass http://${aws_lb.internal_alb.dns_name};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /parking/ {
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

    location /booking/ {
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

    location /payment/ {
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

    location /notification/ {
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

docker pull "$FRONTEND_IMAGE"
docker rm -f smart-parking-frontend || true
docker run -d \
  --name smart-parking-frontend \
  --restart unless-stopped \
  -p 127.0.0.1:8080:80 \
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
  vpc_zone_identifier       = [for s in aws_subnet.public_subnets : s.id]
  target_group_arns         = [aws_lb_target_group.web_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}
