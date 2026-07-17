# ============================================================
# RDS のテスト
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
# 公開設定（最重要）
# ------------------------------------------------------------

run "rds_is_not_publicly_accessible" {
  assert {
    condition     = aws_db_instance.rds.publicly_accessible == false
    error_message = "RDS がインターネットに公開されている"
  }

  assert {
    condition     = aws_db_instance.rds.vpc_security_group_ids == toset([aws_security_group.rds.id])
    error_message = "RDS に RDS用SG だけが付いていない"
  }
}

run "rds_lives_only_in_private_subnets" {
  assert {
    condition = aws_db_subnet_group.rds.subnet_ids == toset([
      aws_subnet.private1.id,
      aws_subnet.private2.id,
    ])
    error_message = "DBサブネットグループがプライベートサブネット2つで構成されていない"
  }

  # パブリックサブネットが混ざっていないこと
  assert {
    condition = !anytrue([
      contains(aws_db_subnet_group.rds.subnet_ids, aws_subnet.public1.id),
      contains(aws_db_subnet_group.rds.subnet_ids, aws_subnet.public2.id),
    ])
    error_message = "DBサブネットグループにパブリックサブネットが含まれている"
  }

  assert {
    condition     = aws_db_instance.rds.db_subnet_group_name == aws_db_subnet_group.rds.name
    error_message = "RDS が想定のDBサブネットグループを使っていない"
  }
}

# ------------------------------------------------------------
# エンジン / スペック
# ------------------------------------------------------------

run "rds_engine_and_spec" {
  assert {
    condition     = aws_db_instance.rds.engine == "mysql"
    error_message = "エンジンが mysql ではない"
  }

  assert {
    condition     = startswith(aws_db_instance.rds.engine_version, "8.0")
    error_message = "MySQL 8.0系ではない"
  }

  assert {
    condition     = aws_db_instance.rds.instance_class == "db.t3.micro"
    error_message = "インスタンスクラスが想定と違う（学習用途はコスト重視）"
  }

  assert {
    condition     = aws_db_instance.rds.allocated_storage == 20
    error_message = "ストレージサイズが想定と違う"
  }

  assert {
    condition     = aws_db_instance.rds.username == "admin"
    error_message = "マスターユーザー名が想定と違う"
  }
}

# ------------------------------------------------------------
# 学習環境としての割り切り設定
#   本番に転用するときはこの run を落として設定を見直すこと
# ------------------------------------------------------------

run "rds_is_configured_as_a_study_environment" {
  assert {
    condition     = aws_db_instance.rds.multi_az == false
    error_message = "Multi-AZ が有効（学習用途では単一AZの想定）"
  }

  assert {
    condition     = aws_db_instance.rds.skip_final_snapshot == true
    error_message = "destroy 時に最終スナップショットを取る設定になっている"
  }
}
