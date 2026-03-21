resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}
resource "aws_ecr_repository" "ecr_repo" {
  name = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"
}

# IAM stuff --------------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = jsondecode({
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
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# AWS ECS stuff ----------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "${var.project_name}-api"
    image     = "${aws_ecr_repository.ecr_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.project_name}-api"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# AWS CloudWatch stuff
resource "aws_cloudwatch_log_group" "cloud_suite_cloudwatch_log_group" {
  name = "/ecs/${var.project_name}-api"
  retention_in_days = 7
}
# security group for ALB
resource "aws_security_group" "ecs_security_group" {
  name = "${var.project_name}-ecs-security-group"
  vpc_id = var.vpc_id
  description = "This is the security group for ECS containers]"
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
    Name = "${var.project_name}-ecs-security-group"
  }
}

resource "aws_security_group" "alb_security_group" {
  name = "${var.project_name}-alb-security-group"
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
    Name = "${var.project_name}-alb-security-group"
  }
}

resource "aws_lb" "cloud-suite-lb" {
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

resource "aws_lb_target_group" "cloud-suite-lb-tg" {
  name        = "${var.project_name}-lb-tg"
  target_type = "ip"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.cloud-suite-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloud-suite-lb-tg.arn
  }
}