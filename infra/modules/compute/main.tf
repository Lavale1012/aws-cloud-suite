# Compute module - ECS Fargate application layer.
# Traffic flow: User -> ALB (port 80) -> Target Group -> ECS tasks (port 8080)
# Containers pull images from ECR and send logs to CloudWatch.

# ECS cluster - logical grouping for services/tasks
resource "aws_ecs_cluster" "cloud_suite_ecs_cluster" {
  name = "${var.project_name}-cluster"
}

# ECR - Docker image registry. ECS pulls the container image from here.
resource "aws_ecr_repository" "ecr_repo" {
  name = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"
}

# IAM execution role - lets ECS pull images from ECR and write CloudWatch logs.
# Trust policy restricts this role to the ECS tasks service only.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}_ecs_task_execution_role"
  assume_role_policy = jsonencode({
    version = "2012-10-17"
    statement = [
      {
        effect = "Allow"
        principal = {
          service = "ecs-tasks.amazonaws.com"
        }
        action = "sts:AssumeRole"
      }
    ]

  })
}

# Attach AWS-managed policy for ECR pulls + CloudWatch writes
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task definition - container blueprint: 0.25 vCPU, 512MB RAM, port 8080.
# awsvpc mode gives each task its own network interface (required for Fargate).
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}_api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "${var.project_name}_api"
    image     = "${aws_ecr_repository.ecr_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.project_name}_api"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# CloudWatch log group - stores container stdout/stderr, 7-day retention
resource "aws_cloudwatch_log_group" "cloud_suite_cloudwatch_log_group" {
  name = "/ecs/${var.project_name}_api"
  retention_in_days = 7
}

# Security groups - control traffic between ALB and ECS:
#   Internet -> [ALB SG: port 80 in] -> ALB -> [ECS SG: port 8080 from ALB only] -> Tasks

# ECS SG - only accepts traffic on 8080 from the ALB security group
resource "aws_security_group" "ecs_security_group" {
  name = "${var.project_name}_ecs_security_group"
  vpc_id = var.vpc_id
  description = "This is the security group for ECS containers"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_security_group.id]

  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}_ecs_security_group"
  }
}

# ALB SG - accepts HTTP (port 80) from anywhere on the internet
resource "aws_security_group" "alb_security_group" {
  name = "${var.project_name}_alb_security_group"
  vpc_id = var.vpc_id
  description = "This is the security group for ALB"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}_alb_security_group"
  }
}

# ALB - internet-facing load balancer in public subnets, receives traffic on port 80
resource "aws_lb" "cloud_suite_lb" {
  name               = "${var.project_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [var.public_subnet_id, var.public_subnet_id_2]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

# Target group - routes ALB traffic to ECS task IPs on port 8080.
# "ip" target type is required for Fargate (tasks get their own IPs).
resource "aws_lb_target_group" "cloud_suite_lb_tg" {
  name        = "${var.project_name}-lb-tg"
  target_type = "ip"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
}

# Listener - forwards all port 80 requests to the target group
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.cloud_suite_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloud_suite_lb_tg.arn
  }
}

# ECS service - runs 2 Fargate tasks across private subnets for HA.
# Registers tasks with the ALB target group and replaces unhealthy ones.
# No public IPs; outbound traffic goes through the NAT Gateway.
resource "aws_ecs_service" "cloud_suite_ecs_service" {
  name            = "${var.project_name}_ecs_service"
  cluster         = aws_ecs_cluster.cloud_suite_ecs_cluster.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id_1, var.private_subnet_id_2]
    security_groups  = [aws_security_group.ecs_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cloud_suite_lb_tg.arn
    container_name   = "${var.project_name}_api"
    container_port   = 8080
  }
}
