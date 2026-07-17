# ============================================================
# Terraform / Provider バージョン制約
# ============================================================

terraform {
  # mock_provider（terraform test のモック機能）を使うため 1.7 以上が必要
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
