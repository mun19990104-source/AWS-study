# ============================================================
# Variables (CloudFormation Parameters に相当)
# ============================================================

variable "region" {
  type        = string
  default     = "ap-northeast-1"
  description = "デプロイ先リージョン"
}

variable "stack_name" {
  type        = string
  default     = "aws-study"
  description = "スタック名（リソース名のプレフィックスに使用）"
}

# ------------------------------------------------------------
# EC2
# ------------------------------------------------------------

variable "key_name" {
  type        = string
  description = "EC2キーペア名"
}

variable "ami_id" {
  type        = string
  default     = "ami-088b486f20fab3f0e"
  description = "Amazon Linux 2023 AMI ID"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2インスタンスタイプ"

  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "t3.nano / t3.micro / t3.small / t3.medium のいずれかを指定してください。"
  }
}

# ------------------------------------------------------------
# RDS
# ------------------------------------------------------------

variable "db_password" {
  type        = string
  sensitive   = true
  description = "RDSマスターユーザーのパスワード"
}

# ------------------------------------------------------------
# Security
# ------------------------------------------------------------

variable "ssh_cidr" {
  type        = string
  description = "SSHを許可するCIDR（例: 203.0.113.5/32）"

  validation {
    condition     = can(regex("^(([0-9]{1,3}\\.){3}[0-9]{1,3})/([0-9]|[1-2][0-9]|3[0-2])$", var.ssh_cidr))
    error_message = "CIDR形式で入力してください（例：203.0.113.5/32）"
  }
}

# ------------------------------------------------------------
# 通知
# ------------------------------------------------------------

variable "alert_email" {
  type        = string
  description = "CloudWatchアラーム通知先のメールアドレス"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "有効なメールアドレスを入力してください"
  }
}
