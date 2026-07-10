module "networking" {
  source = "./modules/networking"

  vpc_cidr            = var.vpc_cidr
  subnet_cidr         = var.subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  aws_region          = var.aws_region
  project_name        = var.project_name
}