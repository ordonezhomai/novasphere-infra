# VPC : module public du registre. Deux zones, subnets publics, pas de NAT Gateway.
module "vpc" {
  #checkov:skip=CKV_TF_1:Module du registre public epingle par version (~> 6.0), version exacte figee par .terraform.lock.hcl
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr

  azs            = var.azs
  public_subnets = var.public_subnets

  enable_nat_gateway      = false # facturee a l'heure, inutile : les instances sortent par l'Internet Gateway
  map_public_ip_on_launch = true  # IP publique pour sortir vers les depots et l'API SSM
}
