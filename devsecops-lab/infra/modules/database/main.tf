resource "aws_db_subnet_group" "main" {
  name        = "${var.environment}-db-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for RDS PostgreSQL instance"

  tags = {
    Environment = var.environment
  }
}

resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "devsecops-lab/${var.environment}/rds-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_secret_ver" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    username = var.db_username
    password = random_password.db_password.result
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.environment}-devsecops-postgres"
  engine                 = "postgres"
  engine_version         = "16.1"
  instance_class         = var.db_instance_class # Free Tier db.t4g.micro or db.t3.micro
  allocated_storage      = 20                     # 20 GB Free Tier limit
  max_allocated_storage  = 20
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name        = "${var.environment}-rds-postgres"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
