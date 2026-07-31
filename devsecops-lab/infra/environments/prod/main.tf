module "network" {
  source               = "../../modules/network"
  environment          = "prod"
  vpc_cidr             = "10.30.0.0/16"
  public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs = ["10.30.10.0/24", "10.30.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
}

module "database" {
  source            = "../../modules/database"
  environment       = "prod"
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.rds_security_group_id
  db_name           = "prod_lab_db"
  db_username       = "prodadmin"
  db_instance_class = "db.t4g.micro"
}

module "compute" {
  source                = "../../modules/compute"
  environment           = "prod"
  aws_region            = var.aws_region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  ecs_security_group_id = module.network.ecs_security_group_id
  db_host               = module.database.address
  db_port               = module.database.port
  db_name               = module.database.db_name
  db_user               = "prodadmin"
  db_secret_arn         = module.database.secret_arn
  image_tag             = var.image_tag
}
