# ============================================================
# 変数バリデーションのテスト
#   validation ブロックが意図通り効くかを確認する。
#   command = plan だけで判定できるのでモックすら不要（最速）。
# ============================================================

mock_provider "aws" {}

variables {
  key_name    = "test-keypair"
  db_password = "TestPassw0rd!"
  ssh_cidr    = "203.0.113.5/32"
  alert_email = "test@example.com"
}

# ------------------------------------------------------------
# instance_type
# ------------------------------------------------------------

run "instance_type_allows_t3_micro" {
  command = plan

  variables {
    instance_type = "t3.micro"
  }

  assert {
    condition     = var.instance_type == "t3.micro"
    error_message = "許可済みのインスタンスタイプが弾かれている"
  }
}

run "instance_type_rejects_m5_large" {
  command = plan

  variables {
    instance_type = "m5.large"
  }

  expect_failures = [var.instance_type]
}

run "instance_type_rejects_typo" {
  command = plan

  variables {
    instance_type = "t3micro"
  }

  expect_failures = [var.instance_type]
}

# ------------------------------------------------------------
# ssh_cidr
# ------------------------------------------------------------

run "ssh_cidr_accepts_host_cidr" {
  command = plan

  variables {
    ssh_cidr = "198.51.100.10/32"
  }

  assert {
    condition     = var.ssh_cidr == "198.51.100.10/32"
    error_message = "正しいCIDRが弾かれている"
  }
}

run "ssh_cidr_rejects_missing_prefix" {
  command = plan

  variables {
    ssh_cidr = "203.0.113.5"
  }

  expect_failures = [var.ssh_cidr]
}

run "ssh_cidr_rejects_out_of_range_prefix" {
  command = plan

  variables {
    ssh_cidr = "203.0.113.5/33"
  }

  expect_failures = [var.ssh_cidr]
}

# ------------------------------------------------------------
# alert_email
# ------------------------------------------------------------

run "alert_email_rejects_missing_at" {
  command = plan

  variables {
    alert_email = "invalid-email.example.com"
  }

  expect_failures = [var.alert_email]
}

run "alert_email_rejects_missing_tld" {
  command = plan

  variables {
    alert_email = "user@example"
  }

  expect_failures = [var.alert_email]
}
