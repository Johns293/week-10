variable "flask_app" {
  description = "FLASK APP variable"
  default = "app"
}
variable "flask_env" {
  description = "FLASK ENV variable"
  default = "dev"
}
variable "flask_app_home" {
  description = "APP HOME variable"
  default = "/usr/src/app/"
}

variable "flask_app_port" {
  description = "Port exposed by the flask application"
  default = 5000
}
variable "flask_app_image" {
  description = "Dockerhub image for flask-app"
  default = "docker.io/****/terraform-flask-postgres-docker:latest"
}

variable "postgres_db_port" {
  description = "Port exposed by the RDS instance"
  default = 5432
}