# ============================================================
# Security Groups
# ============================================================

# ------------------------------------------------------------
# ALB: インターネットから HTTP を受ける
# ------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "ALBSecurityGroup"
  description = "Allow HTTP to ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALBSecurityGroup"
  }
}

# ------------------------------------------------------------
# EC2: SSH(指定CIDR) + 8080(ALBのみ)
# ------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "EC2SecurityGroup"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 元ファイル同様、このSGにはNameタグなし（付けたい場合は tags を追加）
}

# ------------------------------------------------------------
# RDS: MySQL(3306) を EC2 からのみ
# ------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "RDSSecurityGroup"
  description = "Allow MySQL from EC2"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDSSecurityGroup"
  }
}
