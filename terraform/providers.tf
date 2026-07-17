# ============================================================
# Provider
# ============================================================

provider "aws" {
  region = var.region

  # 全リソースに共通タグを付けたい場合はここを有効化する
  # （既存リソースにタグ差分が出るため、適用前に plan で確認すること）
  # default_tags {
  #   tags = {
  #     Project   = var.stack_name
  #     ManagedBy = "Terraform"
  #   }
  # }
}
