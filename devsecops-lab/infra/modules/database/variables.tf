variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private Subnet IDs for RDS"
}

variable "security_group_id" {
  type        = string
  description = "RDS Security Group ID"
}

variable "db_name" {
  type        = string
  default     = "devsecops_lab_db"
  description = "Database name"
}

variable "db_username" {
  type        = string
  default     = "labuser"
  description = "Database admin username"
}

variable "db_instance_class" {
  type        = string
  default     = "db.t4g.micro"
  description = "AWS Free Tier compliant RDS instance class"
}
