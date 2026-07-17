# ============================================================
# RDS
# ============================================================

resource "aws_db_subnet_group" "rds" {
  name       = "mydbsubnetgroup"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "MyDBSubnetGroup"
  }
}

resource "aws_db_instance" "rds" {
  instance_class         = "db.t3.micro"
  engine                 = "mysql"
  engine_version         = "8.0.45"
  username               = "admin"
  password               = var.db_password
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "MyRDSInstance"
  }
}
