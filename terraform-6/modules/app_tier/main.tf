locals {
  booking_sns_topic_arns = compact([
    var.booking_confirmed_sns_topic_arn,
    var.booking_cancelled_sns_topic_arn
  ])
}

resource "aws_iam_role" "app_dynamodb_role" {
  name = "quickslot-app-runtime-role"

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
    ],
  })
}

resource "aws_iam_role_policy" "app_dynamodb_policy" {
  name = "quickslot-app-runtime-policy"
  role = aws_iam_role.app_dynamodb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = concat(var.dynamodb_table_arns, var.dynamodb_table_index_arns)
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage"
        ]
        Resource = [
          var.sqs_notification_queue_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.payment_invoice_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          var.payment_invoice_bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          var.payment_invoice_kms_key_arn
        ]
      }
      ],
      var.app_config_secret_arn != "" ? [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = [
            var.app_config_secret_arn
          ]
        }
      ] : [],
      length(local.booking_sns_topic_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "sns:GetTopicAttributes",
            "sns:Publish"
          ]
          Resource = local.booking_sns_topic_arns
        }
      ] : []
    )
  })
}

resource "aws_iam_instance_profile" "app_dynamodb_profile" {
  name = "quickslot-app-runtime-profile"
  role = aws_iam_role.app_dynamodb_role.name
}

resource "aws_launch_template" "app" {
  name_prefix   = "smart-parking-app-"
  image_id      = var.ami_id
  instance_type = var.app_instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.app_dynamodb_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
set -euxo pipefail

AUTH_SERVICE_IMAGE="${var.auth_service_image}"
PARKING_SERVICE_IMAGE="${var.parking_service_image}"
BOOKING_SERVICE_IMAGE="${var.booking_service_image}"
PAYMENT_SERVICE_IMAGE="${var.payment_service_image}"
SCHEDULER_SERVICE_IMAGE="${var.scheduler_service_image}"
NOTIFICATION_SERVICE_IMAGE="${var.notification_service_image}"
APP_CONFIG_SECRET_ARN="${var.app_config_secret_arn}"
ENV_DIR="/opt/smart-parking-env"
APP_NETWORK="smart-parking-app"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y awscli docker.io jq nginx

systemctl enable docker
systemctl start docker
systemctl enable nginx
systemctl start nginx

mkdir -p "$ENV_DIR"
docker network create "$APP_NETWORK" || true

APP_SECRET_JSON="{}"
if [ -n "$APP_CONFIG_SECRET_ARN" ]; then
  APP_SECRET_JSON="$(aws secretsmanager get-secret-value \
    --secret-id "$APP_CONFIG_SECRET_ARN" \
    --region "${var.aws_region}" \
    --query SecretString \
    --output text 2>/dev/null || printf '{}')"
fi

secret_value() {
  key="$1"
  fallback="$2"
  value="$(printf '%s' "$APP_SECRET_JSON" | jq -r --arg key "$key" 'if has($key) and .[$key] != null and .[$key] != "" then .[$key] else empty end')"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

JWT_SECRET_VALUE="$(secret_value JWT_SECRET smartparking_super_secret)"
INTERNAL_API_KEY_VALUE="$(secret_value INTERNAL_API_KEY smartparking_internal_key)"
SEED_ADMIN_EMAIL_VALUE="$(secret_value SEED_ADMIN_EMAIL admin@parking.com)"
SEED_ADMIN_PASSWORD_VALUE="$(secret_value SEED_ADMIN_PASSWORD Admin@123)"
SEED_USER_EMAIL_VALUE="$(secret_value SEED_USER_EMAIL user@parking.com)"
SEED_USER_PASSWORD_VALUE="$(secret_value SEED_USER_PASSWORD User@123)"
RAZORPAY_KEY_ID_VALUE="$(secret_value RAZORPAY_KEY_ID rzp_test_ShFFMxa9JkqmZu)"
RAZORPAY_KEY_SECRET_VALUE="$(secret_value RAZORPAY_KEY_SECRET 1I4sLVIvCMWSTUlM5lCZm71j)"
RAZORPAY_CURRENCY_VALUE="$(secret_value RAZORPAY_CURRENCY INR)"

cat <<EOT > "$ENV_DIR/auth-service.env"
PORT=4001
AWS_REGION=${var.aws_region}
AUTH_USERS_TABLE=${var.auth_users_table}
JWT_SECRET=$JWT_SECRET_VALUE
JWT_EXPIRES_IN=7d
CORS_ORIGIN=*
SEED_ADMIN_EMAIL=$SEED_ADMIN_EMAIL_VALUE
SEED_ADMIN_PASSWORD=$SEED_ADMIN_PASSWORD_VALUE
SEED_USER_EMAIL=$SEED_USER_EMAIL_VALUE
SEED_USER_PASSWORD=$SEED_USER_PASSWORD_VALUE
EOT

cat <<EOT > "$ENV_DIR/parking-service.env"
PORT=4002
AWS_REGION=${var.aws_region}
PARKING_SLOTS_TABLE=${var.parking_slots_table}
JWT_SECRET=$JWT_SECRET_VALUE
CORS_ORIGIN=*
INTERNAL_API_KEY=$INTERNAL_API_KEY_VALUE
EOT

cat <<EOT > "$ENV_DIR/booking-service.env"
PORT=4003
AWS_REGION=${var.aws_region}
BOOKING_TABLE=${var.booking_table}
SQS_NOTIFICATION_QUEUE_NAME=${var.sqs_notification_queue_name}
SQS_NOTIFICATION_QUEUE_URL=${var.sqs_notification_queue_url}
BOOKING_CONFIRMED_SNS_TOPIC_ARN=${var.booking_confirmed_sns_topic_arn}
BOOKING_CANCELLED_SNS_TOPIC_ARN=${var.booking_cancelled_sns_topic_arn}
JWT_SECRET=$JWT_SECRET_VALUE
CORS_ORIGIN=*
PARKING_SERVICE_URL=http://parking-service:4002
NOTIFICATION_SERVICE_URL=http://notification-service:4006
INTERNAL_API_KEY=$INTERNAL_API_KEY_VALUE
BOOKING_HOLD_MINUTES=10
EOT

cat <<EOT > "$ENV_DIR/payment-service.env"
PORT=4004
AWS_REGION=${var.aws_region}
PAYMENT_TABLE=${var.payment_table}
PAYMENT_INVOICE_BUCKET=${var.payment_invoice_bucket_name}
PAYMENT_INVOICE_KMS_KEY_ARN=${var.payment_invoice_kms_key_arn}
SQS_NOTIFICATION_QUEUE_NAME=${var.sqs_notification_queue_name}
SQS_NOTIFICATION_QUEUE_URL=${var.sqs_notification_queue_url}
JWT_SECRET=$JWT_SECRET_VALUE
CORS_ORIGIN=*
BOOKING_SERVICE_URL=http://booking-service:4003
NOTIFICATION_SERVICE_URL=http://notification-service:4006
INTERNAL_API_KEY=$INTERNAL_API_KEY_VALUE
RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID_VALUE
RAZORPAY_KEY_SECRET=$RAZORPAY_KEY_SECRET_VALUE
RAZORPAY_CURRENCY=$RAZORPAY_CURRENCY_VALUE
EOT

cat <<EOT > "$ENV_DIR/scheduler-service.env"
PORT=4005
AWS_REGION=${var.aws_region}
BOOKING_TABLE=${var.booking_table}
BOOKING_SERVICE_URL=http://booking-service:4003
INTERNAL_API_KEY=$INTERNAL_API_KEY_VALUE
CRON_SCHEDULE=* * * * *
EOT

cat <<EOT > "$ENV_DIR/notification-service.env"
PORT=4006
AWS_REGION=${var.aws_region}
NOTIFICATION_TABLE=${var.notification_table}
SQS_NOTIFICATION_QUEUE_NAME=${var.sqs_notification_queue_name}
SQS_NOTIFICATION_QUEUE_URL=${var.sqs_notification_queue_url}
BOOKING_CONFIRMED_SNS_TOPIC_ARN=${var.booking_confirmed_sns_topic_arn}
BOOKING_CANCELLED_SNS_TOPIC_ARN=${var.booking_cancelled_sns_topic_arn}
JWT_SECRET=$JWT_SECRET_VALUE
CORS_ORIGIN=*
INTERNAL_API_KEY=$INTERNAL_API_KEY_VALUE
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

    location = /booking/book-slot {
        rewrite ^ /bookings break;
        proxy_pass http://127.0.0.1:4003;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /api/booking/book-slot {
        rewrite ^ /bookings break;
        proxy_pass http://127.0.0.1:4003;
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

    location = /payment/create-order {
        rewrite ^ /payments/razorpay/order break;
        proxy_pass http://127.0.0.1:4004;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /api/payment/create-order {
        rewrite ^ /payments/razorpay/order break;
        proxy_pass http://127.0.0.1:4004;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /payment/verify-payment {
        rewrite ^ /payments/razorpay/verify break;
        proxy_pass http://127.0.0.1:4004;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /api/payment/verify-payment {
        rewrite ^ /payments/razorpay/verify break;
        proxy_pass http://127.0.0.1:4004;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /payment/process-payment {
        rewrite ^ /payments/process break;
        proxy_pass http://127.0.0.1:4004;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /api/payment/process-payment {
        rewrite ^ /payments/process break;
        proxy_pass http://127.0.0.1:4004;
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

    location = /health {
        proxy_pass http://127.0.0.1:4001/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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
  vpc_zone_identifier = var.app_private_subnet_ids
  target_group_arns = concat(
    [var.app_target_group_arn],
    var.service_target_group_arns
  )
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "backend-server"
    propagate_at_launch = true
  }
}
