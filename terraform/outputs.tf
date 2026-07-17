# ============================================================
# Outputs
# ============================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "alb_dns_name" {
  description = "ALBのDNS名（ブラウザでアクセスする先）"
  value       = aws_lb.alb.dns_name
}

output "ec2_public_ip" {
  description = "EC2のパブリックIP（SSH接続先）"
  value       = aws_instance.ec2.public_ip
}

output "rds_endpoint" {
  description = "RDSの接続エンドポイント"
  value       = aws_db_instance.rds.address
}

output "sns_topic_arn" {
  description = "アラーム通知用SNSトピックARN"
  value       = aws_sns_topic.alarm.arn
}
