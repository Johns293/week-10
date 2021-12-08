resource "aws_vpc" "week-10-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "week-10-vpc"
    }
}

# subnet

resource "aws_subnet" "public-subnet" {
    vpc_id                  = aws_vpc.week-10-vpc.id
    cidr_block              = "10.0.0.0/24"
}
resource "aws_subnet" "public-subnet-2" {
    vpc_id                  = aws_vpc.week-10-vpc.id
    cidr_block              = "10.0.1.0/24"
}
resource "aws_subnet" "public-subnet-1" {
    vpc_id                  = aws_vpc.week-10-vpc.id
    cidr_block              = "10.0.3.0/24"
    availability_zone       = "eu-west-1b"
}

# internet gateway

resource "aws_internet_gateway" "week-10-IGW" {
    vpc_id = aws_vpc.week-10-vpc.id
}
# Route Table 

resource "aws_route_table" "public-route" {
    vpc_id = aws_vpc.week-10-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.week-10-IGW.id
    }
}

resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.public-subnet.id

    route_table_id = aws_route_table.public-route.id
}

resource "aws_route_table_association" "route_table_association-1" {
    subnet_id      = aws_subnet.public-subnet-1.id

    route_table_id = aws_route_table.public-route.id
}

resource "aws_route_table_association" "route_table_association-2" {
    subnet_id      =  aws_subnet. public-subnet-2.id
    route_table_id = aws_route_table.public-route.id
}

# Security Groups

resource "aws_security_group" "week-10-sg" {
    vpc_id      = aws_vpc.week-10-vpc.id

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    egress {
        from_port       = 0
        to_port         = 65535
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "rds_sg" {
    vpc_id      = aws_vpc.week-10-vpc.id

    ingress {
        protocol        = "tcp"
        from_port       = 3306
        to_port         = 3306
        cidr_blocks     = ["0.0.0.0/0"]
        security_groups = [aws_security_group.week-10-sg.id]
    }

    egress {
        from_port       = 0
        to_port         = 65535
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
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

# EC2
resource "aws_launch_configuration" "ecs_launch_config" {
    image_id             = "ami-04dd4500af104442f" 
    iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
    security_groups      = [aws_security_group.week-10-sg.id]
    user_data            = "#!/bin/bash\necho ECS_CLUSTER=my-cluster >> /etc/ecs/ecs.config"
    instance_type        = "t2.micro"
}

resource "aws_autoscaling_group" "failure_analysis_ecs_asg" {
    name                      = "asg"
    vpc_zone_identifier       = [aws_subnet.public-subnet.id]
    launch_configuration      = aws_launch_configuration.ecs_launch_config.name

    desired_capacity          = 2
    min_size                  = 1
    max_size                  = 10
    health_check_grace_period = 300
    health_check_type         = "EC2"
}

# Database Instance
resource "aws_db_subnet_group" "db_subnet_group" {
    subnet_ids  = [aws_subnet.public-subnet.id, aws_subnet.public-subnet-2.id,aws_subnet.public-subnet-1.id]
}

# RDS
resource "aws_db_instance" "mysql" {
    identifier                = "mysql"
    allocated_storage         = 5
    backup_retention_period   = 2
    backup_window             = "01:00-01:30"
    maintenance_window        = "sun:03:00-sun:03:30"
    multi_az                  = true
    engine                    = "mysql"
    engine_version            = "5.7"
    instance_class            = "db.t2.micro"
    name                      = "worker_db"
    username                  = "Bigmanishere"
    password                  = "Bigmanishere"
    port                      = "3306"
    db_subnet_group_name      = aws_db_subnet_group.db_subnet_group.id
    vpc_security_group_ids    = [aws_security_group.rds_sg.id, aws_security_group.week-10-sg.id]
    skip_final_snapshot       = true
    final_snapshot_identifier = "worker-final"
    publicly_accessible       = true
}

# Elastic Container Service Repo
resource "aws_ecr_repository" "worker" {
    name  = "worker"
}

# output

output "mysql_endpoint" {
    value = aws_db_instance.mysql.endpoint
}
output "ecr_repository_worker_endpoint" {
    value = aws_ecr_repository.worker.repository_url
}

data "template_file" "task_definition_template" {
  template = file("task_definition.json.tpl")
  vars = {
    REPOSITORY_URL = var.flask_app_image
    FLASK_APP = var.flask_app
    FLASK_ENV = var.flask_env
    FLASK_APP_HOME = var.flask_app_home
    FLASK_APP_PORT = var.flask_app_port

  }
}

# ALB
# create the ALB
resource "aws_alb" "week-10-alb" {
  load_balancer_type = "application"
  name = "application-load-balancer"
  subnets = [aws_subnet.public-subnet.id, aws_subnet.public-subnet-1.id]
  security_groups = [aws_security_group.week-10-sg.id]
}

# point redirected traffic to the app
resource "aws_alb_target_group" "target_group" {
  name = "ecs-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.week-10-vpc.id
  target_type = "ip"
}

# direct traffic through the ALB
resource "aws_alb_listener" "fp-alb-listener" {
  load_balancer_arn = aws_alb.week-10-alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.target_group.arn
    type = "forward"
  }
}
