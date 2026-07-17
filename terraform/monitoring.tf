# ============================================================
# SNS (アラーム通知先)
# ============================================================

resource "aws_sns_topic" "alarm" {
  name = "${var.stack_name}-alarm-topic"

  tags = {
    Name = "${var.stack_name}-alarm-topic"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# CloudWatch Alarm
# ============================================================

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name        = "AWS-study-EC2CPUUtilizationAlarm"
  alarm_description = "AWS EC2のCPU使用率が2%を超えた場合にアラームを発生させる。"
  namespace         = "AWS/EC2"
  metric_name       = "CPUUtilization"

  dimensions = {
    InstanceId = aws_instance.ec2.id
  }

  unit                = "Percent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  treat_missing_data  = "missing"
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alarm.arn]
}
