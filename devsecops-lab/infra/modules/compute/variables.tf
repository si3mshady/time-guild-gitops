variable "environment" {
  type        = string
  description = "Target environment name"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public Subnet IDs for ALB and ECS tasks"
}

variable "alb_security_group_id" {
  type        = string
  description = "ALB Security Group ID"
}

variable "ecs_security_group_id" {
  type        = string
  description = "ECS Task Security Group ID"
}

variable "db_host" {
  type        = string
  description = "RDS Endpoint address"
}

variable "db_port" {
  type        = number
  default     = 5432
  description = "RDS Port"
}

variable "db_name" {
  type        = string
  default     = "devsecops_lab_db"
  description = "RDS Database name"
}

variable "db_user" {
  type        = string
  default     = "labuser"
  description = "RDS Master username"
}

variable "db_secret_arn" {
  type        = string
  description = "AWS Secrets Manager Secret ARN storing DB password"
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "ECR Image tag for Next.js app"
}
