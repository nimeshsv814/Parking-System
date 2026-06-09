resource "aws_instance" "database" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name

  subnet_id = aws_subnet.db_private_subnets["data-private-subnet-1a"].id

  vpc_security_group_ids = [
    aws_security_group.db-sg.id
  ]

  associate_public_ip_address = false
  user_data_replace_on_change = true

  depends_on = [
    aws_nat_gateway.nat,
    aws_route_table_association.db-pri
  ]

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

MONGODB_IMAGE="${var.mongodb_image}"

export DEBIAN_FRONTEND=noninteractive

for attempt in {1..12}; do
  if apt-get update -y; then
    break
  fi
  sleep 10
done
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

docker pull "$MONGODB_IMAGE"
docker volume create smart-parking-mongo-data || true
docker rm -f mongodb || true
docker run -d \
  --name mongodb \
  --restart unless-stopped \
  -p 27017:27017 \
  -v smart-parking-mongo-data:/data/db \
  "$MONGODB_IMAGE"

EOF

  tags = {
    Name = "Database"
  }
}
