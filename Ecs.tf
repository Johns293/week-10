
resource "aws_ecs_cluster" "week-10-cluster" {
  name = "student"

  tags = {
    Name = "student"
  }
}

# Task definition
resource "aws_ecs_task_definition" "task-definition" {
  family = "student-10"
  requires_compatibilities = [
    "FARGATE"]
  network_mode = "none"
  cpu = 256
  memory = 512
  container_definitions = data.template_file.task_definition_template.rendered
}

resource "aws_ecs_service" "task-definition" {
  name = "flask-app-service"
  cluster = aws_ecs_cluster.week-10-cluster.id
  task_definition = aws_ecs_task_definition.task-definition.arn
  desired_count = 2
  launch_type = "FARGATE"

  network_configuration {
    security_groups = [
      aws_security_group.week-10-sg.id]
    subnets = [aws_subnet.public-subnet-1.id,aws_subnet.public-subnet-2.id]
    assign_public_ip = true
  }

  load_balancer {
    container_name = "worker"
    container_port = var.flask_app_port
    target_group_arn = aws_alb_target_group.target_group.id
  }

  depends_on = [
    aws_alb_listener.fp-alb-listener
  ]
}

# Elastic Container Service Repo
resource "aws_ecr_repository" "worker" {
    name  = "worker"
}