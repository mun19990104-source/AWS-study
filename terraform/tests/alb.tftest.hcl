# ============================================================
# ALB のテスト
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
# ALB 本体
# ------------------------------------------------------------

run "alb_is_internet_facing_and_multi_az" {
  assert {
    condition     = aws_lb.alb.internal == false
    error_message = "ALB が internal になっている（インターネット向けのはず）"
  }

  assert {
    condition     = aws_lb.alb.load_balancer_type == "application"
    error_message = "ロードバランサータイプが application ではない"
  }

  # ALB は最低2つのサブネット（別AZ）が必須
  assert {
    condition     = length(aws_lb.alb.subnets) == 2
    error_message = "ALB のサブネットが2つではない"
  }

  assert {
    condition = alltrue([
      contains(aws_lb.alb.subnets, aws_subnet.public1.id),
      contains(aws_lb.alb.subnets, aws_subnet.public2.id),
    ])
    error_message = "ALB がパブリックサブネットに配置されていない"
  }

  # プライベートサブネットが混ざっていないこと
  assert {
    condition = !anytrue([
      contains(aws_lb.alb.subnets, aws_subnet.private1.id),
      contains(aws_lb.alb.subnets, aws_subnet.private2.id),
    ])
    error_message = "ALB にプライベートサブネットが指定されている"
  }

  assert {
    condition     = contains(aws_lb.alb.security_groups, aws_security_group.alb.id)
    error_message = "ALB に ALB用SG が付いていない"
  }
}

# ------------------------------------------------------------
# ターゲットグループ
# ------------------------------------------------------------

run "target_group_points_to_8080" {
  assert {
    condition     = aws_lb_target_group.tg.port == 8080
    error_message = "TG のポートが 8080 ではない"
  }

  assert {
    condition     = aws_lb_target_group.tg.protocol == "HTTP"
    error_message = "TG のプロトコルが HTTP ではない"
  }

  assert {
    condition     = aws_lb_target_group.tg.target_type == "instance"
    error_message = "TG のターゲットタイプが instance ではない"
  }

  assert {
    condition     = aws_lb_target_group.tg.vpc_id == aws_vpc.vpc.id
    error_message = "TG が対象VPCに属していない"
  }
}

run "target_group_health_check_is_sane" {
  assert {
    condition     = aws_lb_target_group.tg.health_check[0].path == "/"
    error_message = "ヘルスチェックパスが / ではない"
  }

  # timeout < interval でないとヘルスチェックが破綻する
  assert {
    condition     = aws_lb_target_group.tg.health_check[0].timeout < aws_lb_target_group.tg.health_check[0].interval
    error_message = "ヘルスチェックの timeout が interval 以上になっている"
  }

  assert {
    condition     = aws_lb_target_group.tg.health_check[0].healthy_threshold >= 2
    error_message = "healthy_threshold が小さすぎる"
  }
}

# ------------------------------------------------------------
# ターゲット登録 / リスナー
# ------------------------------------------------------------

run "ec2_is_registered_to_target_group" {
  assert {
    condition     = aws_lb_target_group_attachment.ec2.target_id == aws_instance.ec2.id
    error_message = "EC2 が TG に登録されていない"
  }

  # 登録ポートとTGのポートが一致していること
  assert {
    condition     = aws_lb_target_group_attachment.ec2.port == aws_lb_target_group.tg.port
    error_message = "ターゲット登録ポートと TG のポートが食い違っている"
  }
}

run "listener_forwards_80_to_target_group" {
  assert {
    condition     = aws_lb_listener.http.port == 80
    error_message = "リスナーのポートが 80 ではない"
  }

  assert {
    condition     = aws_lb_listener.http.protocol == "HTTP"
    error_message = "リスナーのプロトコルが HTTP ではない"
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "forward"
    error_message = "デフォルトアクションが forward ではない"
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].target_group_arn == aws_lb_target_group.tg.arn
    error_message = "リスナーの転送先が想定の TG ではない"
  }

  assert {
    condition     = aws_lb_listener.http.load_balancer_arn == aws_lb.alb.arn
    error_message = "リスナーが想定の ALB に紐づいていない"
  }
}
