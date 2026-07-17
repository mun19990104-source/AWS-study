# ============================================================
# 統合テスト（実AWSのプロバイダに対して検証する）
#
#   実行:
#     terraform test -test-directory=tests-integration
#
#   前提:
#     - AWSクレデンシャルが設定済みであること
#     - TF_VAR_db_password などの変数が渡されていること
#
#   ここの run はすべて command = plan なので **リソースは作られず課金もされない**。
#   ただしプロバイダのスキーマ検証・値の妥当性チェックは本物が走るため、
#   モックでは見つからない「apply時に初めて落ちる系」のミスを検出できる。
# ============================================================

variables {
  key_name    = "test-keypair"
  ssh_cidr    = "203.0.113.5/32"
  alert_email = "test@example.com"
  # db_password は環境変数で渡す:
  #   export TF_VAR_db_password='...'
}

# ------------------------------------------------------------
# 実プロバイダで plan が通ること
#   AMI IDの形式、インスタンスクラスとエンジンの組み合わせ、
#   WAFのルール構造など、AWSプロバイダ側のバリデーションを通す
# ------------------------------------------------------------

run "plan_succeeds_against_real_provider" {
  command = plan

  assert {
    condition     = aws_vpc.vpc.cidr_block == "10.0.0.0/16"
    error_message = "plan は通ったが VPC の設定が想定と違う"
  }
}

# ------------------------------------------------------------
# 実在するAZが2つ以上あること
#   モックでは検出できない「そのリージョンのAZ数」を実データで確認する
# ------------------------------------------------------------

run "region_has_at_least_two_azs" {
  command = plan

  assert {
    condition     = length(data.aws_availability_zones.available.names) >= 2
    error_message = "対象リージョンに利用可能なAZが2つ未満（ALBとRDSサブネットグループが作れない）"
  }
}

# ------------------------------------------------------------
# 【要注意】実際にリソースを作って確認する版
#
#   有効化すると本当にAWSにリソースが作られる。RDSの作成に10分前後かかり、
#   ALB・RDS・EC2の課金が発生する（テスト終了時に自動でdestroyされるが、
#   途中で中断するとリソースが残るので必ず terraform destroy を確認すること）。
#   学習で「本当に繋がるか」を確かめたいときだけコメントを外す。
# ------------------------------------------------------------

# run "apply_creates_reachable_alb" {
#   command = apply
#
#   assert {
#     condition     = length(aws_lb.alb.dns_name) > 0
#     error_message = "ALB の DNS 名が払い出されていない"
#   }
#
#   assert {
#     condition     = length(aws_instance.ec2.public_ip) > 0
#     error_message = "EC2 にパブリックIPが割り当てられていない"
#   }
#
#   assert {
#     condition     = endswith(aws_db_instance.rds.address, ".rds.amazonaws.com")
#     error_message = "RDS のエンドポイントが払い出されていない"
#   }
# }
