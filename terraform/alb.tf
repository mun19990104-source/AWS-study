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

# ------------------------------------------------------------
# Target Group
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Listener
# ------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
