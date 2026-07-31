module "network" {
  source               = "../../modules/network"
  environment          = "staging"
  vpc_cidr             = "10.20.0.0/16"
  public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
}

module "database" {
  source            = "../../modules/database"
  environment       = "staging"
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.rds_security_group_id
  db_name           = "staging_lab_db"
  db_username       = "stageadmin"
  db_instance_class = "db.t4g.micro"
}

module "compute" {
  source                = "../../modules/compute"
  environment           = "staging"
  aws_region            = var.aws_region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  ecs_security_group_id = module.network.ecs_security_group_id
  db_host               = module.database.address
  db_port               = module.database.port
  db_name               = module.database.db_name
  db_user               = "stageadmin"
  db_secret_arn         = module.database.secret_arn
  image_tag             = var.image_tag
}
