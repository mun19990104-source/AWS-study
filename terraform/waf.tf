# ============================================================
# CloudWatch Log Group (WAF用)
#   ロググループ名は "aws-waf-logs-" プレフィックスが必須
# ============================================================

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.stack_name}-alb-acl"
  retention_in_days = 365

  tags = {
    Name = "aws-waf-logs-${var.stack_name}-alb-acl"
  }
}

# ============================================================
# WAF v2 (Web ACL)
# ============================================================

resource "aws_wafv2_web_acl" "waf" {
  name  = "${var.stack_name}-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.stack_name}-web-acl-metric"
  }
}

# ============================================================
# WAF Logging / ALBへの関連付け
# ============================================================

resource "aws_wafv2_web_acl_logging_configuration" "waf" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.waf.arn
}

resource "aws_wafv2_web_acl_association" "waf" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}
