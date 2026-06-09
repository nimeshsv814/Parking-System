resource "aws_instance" "bastion-host" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name
  subnet_id     = var.public_subnet_1a_id
  vpc_security_group_ids = [
    var.bastion_security_group_id
  ]
  associate_public_ip_address = true
  tags = {
    Name = "Bastion-Host"
  }
}
