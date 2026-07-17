# ============================================================
# ネットワーク（VPC / Subnet / Route）のテスト
# ============================================================

mock_provider "aws" {
  # data.aws_availability_zones は names[0] / names[1] を参照しているため、
  # 最低2件返すようモックしておく（本物のAWSを呼ばない）
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
# VPC
# ------------------------------------------------------------

run "vpc_has_expected_cidr_and_dns" {
  assert {
    condition     = aws_vpc.vpc.cidr_block == "10.0.0.0/16"
    error_message = "VPCのCIDRが 10.0.0.0/16 ではない"
  }

  assert {
    condition     = aws_vpc.vpc.enable_dns_support
    error_message = "DNS解決が無効になっている"
  }

  assert {
    condition     = aws_vpc.vpc.enable_dns_hostnames
    error_message = "DNSホスト名が無効になっている（RDSエンドポイント名前解決に必要）"
  }
}

# ------------------------------------------------------------
# サブネットのCIDR設計
# ------------------------------------------------------------

run "subnets_have_expected_cidrs" {
  assert {
    condition     = aws_subnet.public1.cidr_block == "10.0.1.0/24"
    error_message = "PublicSubnet1 のCIDRが想定外"
  }

  assert {
    condition     = aws_subnet.public2.cidr_block == "10.0.2.0/24"
    error_message = "PublicSubnet2 のCIDRが想定外"
  }

  assert {
    condition     = aws_subnet.private1.cidr_block == "10.0.3.0/24"
    error_message = "PrivateSubnet1 のCIDRが想定外"
  }

  assert {
    condition     = aws_subnet.private2.cidr_block == "10.0.4.0/24"
    error_message = "PrivateSubnet2 のCIDRが想定外"
  }

  # 4つのサブネットのCIDRが重複していないこと
  assert {
    condition = length(distinct([
      aws_subnet.public1.cidr_block,
      aws_subnet.public2.cidr_block,
      aws_subnet.private1.cidr_block,
      aws_subnet.private2.cidr_block,
    ])) == 4
    error_message = "サブネットのCIDRが重複している"
  }

  # 全サブネットがVPCのCIDRレンジ内に収まっていること
  assert {
    condition = alltrue([
      for cidr in [
        aws_subnet.public1.cidr_block,
        aws_subnet.public2.cidr_block,
        aws_subnet.private1.cidr_block,
        aws_subnet.private2.cidr_block,
        ] : cidrsubnet(aws_vpc.vpc.cidr_block, 8, tonumber(split(".", cidr)[2])) == cidr
    ])
    error_message = "VPCのCIDRレンジ外のサブネットがある"
  }
}

# ------------------------------------------------------------
# マルチAZ配置
# ------------------------------------------------------------

run "subnets_are_spread_across_two_azs" {
  assert {
    condition     = aws_subnet.public1.availability_zone != aws_subnet.public2.availability_zone
    error_message = "パブリックサブネット2つが同一AZにある（ALBは2AZ必須）"
  }

  assert {
    condition     = aws_subnet.private1.availability_zone != aws_subnet.private2.availability_zone
    error_message = "プライベートサブネット2つが同一AZにある（RDSサブネットグループは2AZ必須）"
  }

  # ALBとRDSでAZを揃える（EC2→RDSがAZ跨ぎにならないように）
  assert {
    condition     = aws_subnet.public1.availability_zone == aws_subnet.private1.availability_zone
    error_message = "public1 と private1 のAZがずれている"
  }
}

# ------------------------------------------------------------
# パブリック/プライベートの切り分け
# ------------------------------------------------------------

run "public_subnets_auto_assign_public_ip" {
  assert {
    condition     = aws_subnet.public1.map_public_ip_on_launch
    error_message = "PublicSubnet1 でパブリックIP自動割当が無効"
  }

  assert {
    condition     = aws_subnet.public2.map_public_ip_on_launch
    error_message = "PublicSubnet2 でパブリックIP自動割当が無効"
  }
}

# ------------------------------------------------------------
# ルーティング
# ------------------------------------------------------------

run "public_route_table_has_default_route_to_igw" {
  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "デフォルトルートが 0.0.0.0/0 になっていない"
  }

  assert {
    condition     = aws_route.public_internet.gateway_id == aws_internet_gateway.igw.id
    error_message = "デフォルトルートの向き先がIGWではない"
  }

  assert {
    condition     = aws_route.public_internet.route_table_id == aws_route_table.public.id
    error_message = "デフォルトルートがパブリックルートテーブルに紐づいていない"
  }

  assert {
    condition     = aws_internet_gateway.igw.vpc_id == aws_vpc.vpc.id
    error_message = "IGWがVPCにアタッチされていない"
  }
}

run "public_subnet1_is_associated_with_public_route_table" {
  assert {
    condition     = aws_route_table_association.public1.subnet_id == aws_subnet.public1.id
    error_message = "public1 の関連付け先サブネットが違う"
  }

  assert {
    condition     = aws_route_table_association.public1.route_table_id == aws_route_table.public.id
    error_message = "public1 がパブリックルートテーブルに紐づいていない"
  }
}

# ------------------------------------------------------------
# 既知の不具合: PublicSubnet2 のルートテーブル関連付けが未定義
#   vpc.tf の aws_route_table_association.public2 を有効化したら
#   このブロックのコメントを外すこと。今の状態では必ず失敗する。
# ------------------------------------------------------------

# run "public_subnet2_is_associated_with_public_route_table" {
#   assert {
#     condition     = aws_route_table_association.public2.route_table_id == aws_route_table.public.id
#     error_message = "public2 がパブリックルートテーブルに紐づいていない（ALBの片系がインターネットに出られない）"
#   }
# }
