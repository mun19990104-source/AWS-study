# ============================================================
# 監視（SNS / CloudWatch Alarm）のテスト
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
# SNS
# ------------------------------------------------------------

run "sns_topic_name_uses_stack_name" {
  variables {
    stack_name = "unittest"
  }

  assert {
    condition     = aws_sns_topic.alarm.name == "unittest-alarm-topic"
    error_message = "var.stack_name が SNS トピック名に反映されていない"
  }
}

run "sns_subscription_sends_email_to_alert_address" {
  variables {
    alert_email = "ops@example.com"
  }

  assert {
    condition     = aws_sns_topic_subscription.email.protocol == "email"
    error_message = "サブスクリプションのプロトコルが email ではない"
  }

  assert {
    condition     = aws_sns_topic_subscription.email.endpoint == "ops@example.com"
    error_message = "var.alert_email が通知先に反映されていない"
  }

  assert {
    condition     = aws_sns_topic_subscription.email.topic_arn == aws_sns_topic.alarm.arn
    error_message = "サブスクリプションが想定のトピックに紐づいていない"
  }
}

# ------------------------------------------------------------
# CloudWatch Alarm
# ------------------------------------------------------------

run "cpu_alarm_watches_the_ec2_instance" {
  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_cpu.namespace == "AWS/EC2"
    error_message = "名前空間が AWS/EC2 ではない"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_cpu.metric_name == "CPUUtilization"
    error_message = "メトリクスが CPUUtilization ではない"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_cpu.dimensions["InstanceId"] == aws_instance.ec2.id
    error_message = "アラームの監視対象が想定の EC2 インスタンスではない"
  }
}

run "cpu_alarm_notifies_sns_topic" {
  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_cpu.actions_enabled
    error_message = "アラームアクションが無効になっている（鳴っても通知が飛ばない）"
  }

  assert {
    condition     = contains(aws_cloudwatch_metric_alarm.ec2_cpu.alarm_actions, aws_sns_topic.alarm.arn)
    error_message = "アラームの通知先に SNS トピックが設定されていない"
  }
}

run "cpu_alarm_threshold_settings_are_consistent" {
  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_cpu.comparison_operator == "GreaterThanOrEqualToThreshold"
    error_message = "比較演算子が想定と違う"
  }

  # datapoints_to_alarm は evaluation_periods 以下でなければ apply が落ちる
  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_cpu.datapoints_to_alarm <= aws_cloudwatch_metric_alarm.ec2_cpu.evaluation_periods
    error_message = "datapoints_to_alarm が evaluation_periods を超えている"
  }

  # period は 10/30 または 60の倍数でなければならない
  assert {
    condition     = contains([10, 30], aws_cloudwatch_metric_alarm.ec2_cpu.period) || aws_cloudwatch_metric_alarm.ec2_cpu.period % 60 == 0
    error_message = "period が CloudWatch の許容値（10, 30, または60の倍数）ではない"
  }

  # 閾値2%は検証用の値。実運用に持っていくときはここで気づけるようにしておく
  assert {
    condition     = aws_cloudwatch_metric_alarm.ec2_cpu.threshold == 2
    error_message = "CPU閾値が2%から変わっている（検証用の値。意図的な変更ならこのテストを更新すること）"
  }
}
