# ============================================================
# EC2 のテスト
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

run "ec2_uses_defaults" {
  assert {
    condition     = aws_instance.ec2.instance_type == "t3.micro"
    error_message = "デフォルトのインスタンスタイプが t3.micro ではない"
  }

  assert {
    condition     = aws_instance.ec2.ami == "ami-088b486f20fab3f0e"
    error_message = "デフォルトAMIが想定と違う"
  }

  assert {
    condition     = aws_instance.ec2.tags["Name"] == "MyEC2Instance"
    error_message = "Nameタグが付いていない"
  }
}

run "ec2_reflects_overridden_variables" {
  variables {
    instance_type = "t3.small"
    key_name      = "another-keypair"
    ami_id        = "ami-0123456789abcdef0"
  }

  assert {
    condition     = aws_instance.ec2.instance_type == "t3.small"
    error_message = "var.instance_type が反映されていない"
  }

  assert {
    condition     = aws_instance.ec2.key_name == "another-keypair"
    error_message = "var.key_name が反映されていない"
  }

  assert {
    condition     = aws_instance.ec2.ami == "ami-0123456789abcdef0"
    error_message = "var.ami_id が反映されていない"
  }
}

run "ec2_is_placed_in_public_subnet_with_ec2_sg" {
  assert {
    condition     = aws_instance.ec2.subnet_id == aws_subnet.public1.id
    error_message = "EC2 が PublicSubnet1 に配置されていない"
  }

  assert {
    condition     = aws_instance.ec2.vpc_security_group_ids == toset([aws_security_group.ec2.id])
    error_message = "EC2 に EC2用SG だけが付いていない"
  }
}
