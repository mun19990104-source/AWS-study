# ============================================================
# Variables (CloudFormation Parameters に相当)
# ============================================================

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
  type    = string
  default = "t3.micro"
  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "t3.nano / t3.micro / t3.small / t3.medium のいずれかを指定してください。"
  }
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "RDSマスターユーザーのパスワード"
}

variable "ssh_cidr" {
  type        = string
  description = "SSHを許可するCIDR（例: 203.0.113.5/32）"
  validation {
    condition     = can(regex("^(([0-9]{1,3}\\.){3}[0-9]{1,3})/([0-9]|[1-2][0-9]|3[0-2])$", var.ssh_cidr))
    error_message = "CIDR形式で入力してください（例：203.0.113.5/32）"
  }
}

variable "alert_email" {
  type        = string
  description = "CloudWatchアラーム通知先のメールアドレス"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "有効なメールアドレスを入力してください"
  }
}

variable "stack_name" {
  type        = string
  default     = "aws-study"
  description = "スタック名（リソース名のプレフィックスに使用）"
}

# ============================================================
# Provider
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1" # 必要に応じて変更
}

# ============================================================
# Data Sources
# ============================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# ============================================================
# Internet Gateway
# ============================================================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    KeyName = "value"
  }
}

# ============================================================
# Route Table
# ============================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# ============================================================
# Subnets
# ============================================================

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet2"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "PrivateSubnet2"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# Security Groups
# ============================================================

resource "aws_security_group" "alb" {
  name        = "ALBSecurityGroup"
  description = "Allow HTTP to ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALBSecurityGroup"
  }
}

resource "aws_security_group" "ec2" {
  name        = "EC2SecurityGroup"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    from_port                = 8080
    to_port                  = 8080
    protocol                 = "tcp"
    security_groups          = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "RDSSecurityGroup"
  description = "Allow MySQL from EC2"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDSSecurityGroup"
  }
}

# ============================================================
# EC2 Instance
# ============================================================

resource "aws_instance" "ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  tags = {
    Name = "MyEC2Instance"
  }
}

# ============================================================
# ALB
# ============================================================

resource "aws_lb" "alb" {
  name               = "MyALB"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
  security_groups    = [aws_security_group.alb.id]

  tags = {
    Name = "MyALB"
  }
}

resource "aws_lb_target_group" "tg" {
  name        = "MyALBTargetGroup"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "MyALBTargetGroup"
  }
}

resource "aws_lb_target_group_attachment" "ec2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.ec2.id
  port             = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ============================================================
# RDS
# ============================================================

resource "aws_db_subnet_group" "rds" {
  name       = "mydbsubnetgroup"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "MyDBSubnetGroup"
  }
}

resource "aws_db_instance" "rds" {
  instance_class         = "db.t3.micro"
  engine                 = "mysql"
  engine_version         = "8.0.45"
  username               = "admin"
  password               = var.db_password
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "MyRDSInstance"
  }
}

# ============================================================
# SNS
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
  alarm_name          = "AWS-study-EC2CPUUtilizationAlarm"
  alarm_description   = "AWS EC2のCPU使用率が2%を超えた場合にアラームを発生させる。"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
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

# ============================================================
# CloudWatch Log Group (WAF用)
# ============================================================

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.stack_name}-alb-acl"
  retention_in_days = 365

  tags = {
    Name = "aws-waf-logs-${var.stack_name}-alb-acl"
  }
}

# ============================================================
# WAF v2
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

resource "aws_wafv2_web_acl_logging_configuration" "waf" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.waf.arn
}

resource "aws_wafv2_web_acl_association" "waf" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}
