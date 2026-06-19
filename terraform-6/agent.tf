data "aws_ami" "ubuntu_agent" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "agent" {
  count = var.enable_agent_instance ? 1 : 0

  name        = "quickslot-agent-sg"
  description = "Public HTTP access for QuickSlot DevOps Co-Pilot Agent"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.agent_http_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "quickslot-agent-sg"
    Application = "smart-parking"
    Service     = "devops-copilot"
  }
}

resource "aws_iam_role" "agent" {
  count = var.enable_agent_instance ? 1 : 0

  name = "quickslot-agent-ec2-role"

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

resource "aws_iam_role_policy" "agent" {
  count = var.enable_agent_instance ? 1 : 0

  name = "quickslot-agent-policy"
  role = aws_iam_role.agent[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadQuickSlotCloudWatch"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "logs:DescribeLogGroups",
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = "*"
      },
      {
        Sid    = "DescribeQuickSlotSecretMetadata"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.agent_secret_name}*",
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:quickslot-*",
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:quickslot/*"
        ]
      },
      {
        Sid    = "RunGuardedSsmChecks"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Sid    = "InvokeQuickSlotIacRunner"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.iac_runner.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "agent_ssm_managed_instance_core" {
  count = var.enable_agent_instance ? 1 : 0

  role       = aws_iam_role.agent[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "agent" {
  count = var.enable_agent_instance ? 1 : 0

  name = "quickslot-agent-ec2-profile"
  role = aws_iam_role.agent[0].name
}

resource "aws_instance" "agent" {
  count = var.enable_agent_instance ? 1 : 0

  ami                         = data.aws_ami.ubuntu_agent.id
  instance_type               = var.agent_instance_type
  subnet_id                   = module.network.public_subnet_ids["web-public-subnet-1a"]
  vpc_security_group_ids      = [aws_security_group.agent[0].id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.agent[0].name
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    instance_metadata_tags      = "enabled"
    http_put_response_hop_limit = 2
  }

  user_data = replace(<<-EOF
#!/bin/bash
set -euo pipefail

APP_USER="ubuntu"
APP_DIR="/opt/quickslot-agent"
REPO_URL="${var.agent_repo_url}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl git nginx python3 python3-pip python3-venv

SSM_DEB="/tmp/amazon-ssm-agent.deb"
curl -fsSL "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb" -o "$SSM_DEB"
dpkg -i "$SSM_DEB" || apt-get install -f -y
systemctl daemon-reload

systemctl enable amazon-ssm-agent
systemctl restart amazon-ssm-agent

if [ ! -d "$APP_DIR/.git" ]; then
  rm -rf "$APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
else
  cd "$APP_DIR"
  git pull --ff-only
fi

cd "$APP_DIR"
python3 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

cat > "$APP_DIR/.env" <<ENVEOF
QUICKSLOT_AGENT_MODE=aws
AWS_REGION=${var.aws_region}
QUICKSLOT_APP_NAME=quickslot
QUICKSLOT_IAC_LAMBDA_NAME=${var.agent_iac_lambda_name}
QUICKSLOT_ALLOWED_INSTANCE_TAG=Application=smart-parking
QUICKSLOT_DEFAULT_SECRET_NAME=${var.agent_secret_name}
QUICKSLOT_DEFAULT_LOG_MINUTES=${var.agent_default_log_minutes}
ENVEOF

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

cat > /etc/systemd/system/quickslot-agent.service <<SERVICEEOF
[Unit]
Description=QuickSlot DevOps Co-Pilot Agent
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/uvicorn app.api:app --host 127.0.0.1 --port 8010
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

cat > /etc/nginx/sites-available/quickslot-agent <<'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8010;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXEOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/quickslot-agent /etc/nginx/sites-enabled/quickslot-agent
nginx -t

systemctl daemon-reload
systemctl enable quickslot-agent
systemctl restart quickslot-agent
systemctl enable nginx
systemctl restart nginx
curl -fsS http://127.0.0.1/health || true
EOF
  , "\r\n", "\n")

  tags = {
    Name        = "quickslot-devops-copilot"
    Application = "smart-parking"
    Service     = "devops-copilot"
  }

  depends_on = [
    aws_iam_role_policy_attachment.agent_ssm_managed_instance_core
  ]
}
