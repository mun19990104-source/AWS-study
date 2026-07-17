# ============================================================
# セキュリティグループのテスト
#   「開いているべきものが開いているか」だけでなく
#   「開いていてはいけないものが閉じているか」も見る。
# ============================================================

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
    }
  }
}

variables {
  key_name    = "test-keypair"
  db_password = "TestPassw0rd!"
  ssh_cidr    = "203.0.113.5/32"
  alert_email = "test@example.com"
}

# ------------------------------------------------------------
# ALB SG
# ------------------------------------------------------------

run "alb_sg_allows_http_from_internet" {
  assert {
    condition = anytrue([
      for r in aws_security_group.alb.ingress :
      r.from_port == 80 && r.to_port == 80 && r.protocol == "tcp" &&
      try(contains(r.cidr_blocks, "0.0.0.0/0"), false)
    ])
    error_message = "ALB SG がインターネットからのHTTP(80)を許可していない"
  }

  # ALBにSSHが空いていないこと
  assert {
    condition = !anytrue([
      for r in aws_security_group.alb.ingress : r.from_port <= 22 && r.to_port >= 22
    ])
    error_message = "ALB SG に SSH(22) が空いている"
  }

  assert {
    condition     = aws_security_group.alb.vpc_id == aws_vpc.vpc.id
    error_message = "ALB SG が対象VPCに属していない"
  }
}

# ------------------------------------------------------------
# EC2 SG
# ------------------------------------------------------------

run "ec2_sg_restricts_ssh_to_given_cidr" {
  variables {
    ssh_cidr = "198.51.100.10/32"
  }

  assert {
    condition = anytrue([
      for r in aws_security_group.ec2.ingress :
      r.from_port == 22 && r.to_port == 22 && r.protocol == "tcp" &&
      try(contains(r.cidr_blocks, "198.51.100.10/32"), false)
    ])
    error_message = "var.ssh_cidr が SSH ルールに反映されていない"
  }

  # SSHが全世界に開いていないこと（これが一番大事）
  assert {
    condition = !anytrue([
      for r in aws_security_group.ec2.ingress :
      r.from_port <= 22 && r.to_port >= 22 &&
      try(contains(r.cidr_blocks, "0.0.0.0/0"), false)
    ])
    error_message = "SSH(22) が 0.0.0.0/0 に開放されている"
  }
}

run "ec2_sg_allows_8080_only_from_alb" {
  assert {
    condition = anytrue([
      for r in aws_security_group.ec2.ingress :
      r.from_port == 8080 && r.to_port == 8080 && r.protocol == "tcp" &&
      try(contains(r.security_groups, aws_security_group.alb.id), false)
    ])
    error_message = "EC2 SG が ALB SG からの 8080 を許可していない"
  }

  # 8080 がCIDR指定で直接公開されていないこと
  assert {
    condition = !anytrue([
      for r in aws_security_group.ec2.ingress :
      r.from_port == 8080 && try(length(r.cidr_blocks), 0) > 0
    ])
    error_message = "8080 がCIDR指定で直接公開されている（ALB経由に限定すべき）"
  }
}

# ------------------------------------------------------------
# RDS SG
# ------------------------------------------------------------

run "rds_sg_allows_mysql_only_from_ec2" {
  assert {
    condition = anytrue([
      for r in aws_security_group.rds.ingress :
      r.from_port == 3306 && r.to_port == 3306 && r.protocol == "tcp" &&
      try(contains(r.security_groups, aws_security_group.ec2.id), false)
    ])
    error_message = "RDS SG が EC2 SG からの MySQL(3306) を許可していない"
  }

  # RDSにCIDRベースのインバウンドが一切ないこと
  assert {
    condition = !anytrue([
      for r in aws_security_group.rds.ingress : try(length(r.cidr_blocks), 0) > 0
    ])
    error_message = "RDS SG にCIDR指定のインバウンドがある（SG参照のみにすべき）"
  }

  assert {
    condition     = aws_security_group.rds.vpc_id == aws_vpc.vpc.id
    error_message = "RDS SG が対象VPCに属していない"
  }
}

# ------------------------------------------------------------
# SG間の依存の向き（WAF→ALB→EC2→RDS の一方通行になっているか）
# ------------------------------------------------------------

run "sg_chain_is_one_directional" {
  # ALB SG は EC2 SG を参照しない（逆流していない）
  assert {
    condition = !anytrue([
      for r in aws_security_group.alb.ingress :
      try(contains(r.security_groups, aws_security_group.ec2.id), false)
    ])
    error_message = "ALB SG が EC2 SG を参照している（想定は EC2→ALB の一方向）"
  }

  # EC2 SG は RDS SG を参照しない
  assert {
    condition = !anytrue([
      for r in aws_security_group.ec2.ingress :
      try(contains(r.security_groups, aws_security_group.rds.id), false)
    ])
    error_message = "EC2 SG が RDS SG を参照している（想定は RDS←EC2 の一方向）"
  }
}
