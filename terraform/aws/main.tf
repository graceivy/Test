# --- root/main.tf ---

module "networking" {
  source           = "./networking"
  vpc_cidr         = local.vpc_cidr
  access_ip        = var.access_ip
  security_groups  = local.security_groups
  public_sn_count  = 2
  private_sn_count = 3
  max_subnets      = 20
  public_cidrs     = [for i in range(2, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)]
  private_cidrs    = [for i in range(1, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)]
  db_subnet_group  = true
}

module "database" {
  source                 = "./database"
  db_storage             = 10
  db_engine_version      = "5.7"
  db_instance_class      = "db.t2.micro"
  dbname                 = var.dbname
  dbuser                 = var.dbuser
  dbpassword             = var.dbpassword
  db_subnet_group_name   = module.networking.db_subnet_group_name
  vpc_security_group_ids = module.networking.vpc_security_group_ids
  db_identifier          = "mtc-db"
  skip_db_snapshot       = true
}

module "alb" {
  source         = "./alb"
  public_sg      = module.networking.public_security_group_ids
  public_subnets = module.networking.public_subnet_id

  tg_port                = 8000
  tg_protocol            = "HTTP"
  vpc_id                 = module.networking.vpc_id
  lb_healthy_threshold   = 2
  lb_unhealthy_threshold = 2
  lb_timeout             = 3
  lb_interval            = 30

  listener_port     = 80
  listener_protocol = "HTTP"
}

module "compute" {
  source = "./compute"

  instance_count = 1
  instance_type  = "t3.micro"
  public_sg      = module.networking.public_security_group_ids
  public_subnets = module.networking.public_subnet_id
  vol_size       = 10

  key_name        = "mtckey"
  public_key_path = "/home/ubuntu/.ssh/keymtc.pub"

  user_data_path = "${path.root}/userdata.tpl"
  dbname         = var.dbname
  dbuser         = var.dbuser
  dbpassword     = var.dbpassword
  db_endpoint    = module.database.db_endpoint

  lb_target_group_arn = module.alb.lb_target_group_arn
  tg_port             = 8000
  
  private_key_path = "/home/ubuntu/.ssh/keymtc"
}

