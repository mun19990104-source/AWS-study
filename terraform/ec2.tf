# ============================================================
# EC2 Instance
# ============================================================


resource "aws_instance" "ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  tags = {
    Name = "MyEC2Instance"
  }
}
