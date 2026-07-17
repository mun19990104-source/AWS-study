# ============================================================
# WAF v2 のテスト
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
# ロググループ
#   WAFのログ出力先は "aws-waf-logs-" プレフィックスが必須。
#   ここを間違えると apply 時にエラーになるので、事前に落としたい。
# ------------------------------------------------------------

run "waf_log_group_name_has_required_prefix" {
  variables {
    stack_name = "unittest"
  }

  assert {
    condition     = startswith(aws_cloudwatch_log_group.waf.name, "aws-waf-logs-")
    error_message = "WAFログ用ロググループ名に 'aws-waf-logs-' プレフィックスがない（AWS側の必須要件）"
  }

  assert {
    condition     = aws_cloudwatch_log_group.waf.name == "aws-waf-logs-unittest-alb-acl"
    error_message = "var.stack_name がロググループ名に反映されていない"
  }

  assert {
    condition     = aws_cloudwatch_log_group.waf.retention_in_days == 365
    error_message = "ログ保持期間が365日ではない"
  }
}

# ------------------------------------------------------------
# Web ACL
# ------------------------------------------------------------

run "web_acl_is_regional_and_default_allow" {
  variables {
    stack_name = "unittest"
  }

  # ALBに紐づけるWebACLは REGIONAL（CLOUDFRONT だとアタッチできない）
  assert {
    condition     = aws_wafv2_web_acl.waf.scope == "REGIONAL"
    error_message = "Web ACL の scope が REGIONAL ではない（ALB にアタッチできない）"
  }

  assert {
    condition     = aws_wafv2_web_acl.waf.name == "unittest-web-acl"
    error_message = "var.stack_name が Web ACL 名に反映されていない"
  }

  assert {
    condition     = length(aws_wafv2_web_acl.waf.default_action[0].allow) == 1
    error_message = "デフォルトアクションが allow になっていない"
  }

  assert {
    condition     = aws_wafv2_web_acl.waf.visibility_config[0].cloudwatch_metrics_enabled
    error_message = "Web ACL のCloudWatchメトリクスが無効"
  }
}

run "web_acl_has_common_rule_set" {
  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.waf.rule :
      r.name == "AWSManagedRulesCommonRuleSet" && r.priority == 1
    ])
    error_message = "AWSManagedRulesCommonRuleSet が priority=1 で設定されていない"
  }

  # ルールのpriorityが重複していないこと（重複すると apply が落ちる）
  assert {
    condition     = length(distinct([for r in aws_wafv2_web_acl.waf.rule : r.priority])) == length(aws_wafv2_web_acl.waf.rule)
    error_message = "Web ACL のルールで priority が重複している"
  }

  # 各ルールに visibility_config が付いていること（必須）
  assert {
    condition = alltrue([
      for r in aws_wafv2_web_acl.waf.rule : length(r.visibility_config) == 1
    ])
    error_message = "visibility_config のないルールがある"
  }
}

# ------------------------------------------------------------
# ログ出力設定 / ALBへの関連付け
# ------------------------------------------------------------

run "waf_logging_and_association_are_wired" {
  assert {
    condition     = contains(aws_wafv2_web_acl_logging_configuration.waf.log_destination_configs, aws_cloudwatch_log_group.waf.arn)
    error_message = "WAFのログ出力先が想定のロググループではない"
  }

  assert {
    condition     = aws_wafv2_web_acl_logging_configuration.waf.resource_arn == aws_wafv2_web_acl.waf.arn
    error_message = "ログ設定が想定の Web ACL に紐づいていない"
  }

  assert {
    condition     = aws_wafv2_web_acl_association.waf.resource_arn == aws_lb.alb.arn
    error_message = "Web ACL が ALB にアタッチされていない"
  }

  assert {
    condition     = aws_wafv2_web_acl_association.waf.web_acl_arn == aws_wafv2_web_acl.waf.arn
    error_message = "アタッチしている Web ACL が想定と違う"
  }
}
