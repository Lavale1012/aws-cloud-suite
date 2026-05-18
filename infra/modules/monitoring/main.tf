resource "aws_sns_topic" "notification_topic" {
  name = "${var.project_name}-notification-topic"
}
resource "aws_sns_topic_subscription" "notification_subscription" {
  topic_arn = aws_sns_topic.notification_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
resource "aws_cloudwatch_metric_alarm" "cloudwatch_alarm" {
  alarm_name                = "${var.project_name}-ecs-cpu-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors ecs cpu utilization"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.notification_topic.arn]
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}
resource "aws_cloudwatch_metric_alarm" "cloudwatch_rds_cpu_alarm" {
  alarm_name                = "${var.project_name}-rds-cpu-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/RDS"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors rds cpu utilization"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.notification_topic.arn]
  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }
}
resource "aws_cloudwatch_metric_alarm" "cloudwatch_alb_alarm" {
  alarm_name                = "${var.project_name}-alb-5xx-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "HTTPCode_ELB_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = 120
  statistic                 = "Sum"
  threshold                 = 10
  alarm_description         = "Monitors ALB 5XX error rate"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.notification_topic.arn]
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}
