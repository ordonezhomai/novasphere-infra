# Valeurs de l'environnement dev : versionnees, relues en PR, aucun secret ici.
locals {
  environment   = "dev"
  name          = "novasphere-${local.environment}"
  vpc_cidr      = "10.0.0.0/16"
  subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  instance_type = "t3.micro"
  asg_min       = 2
  asg_max       = 4
  secret_path   = "/novasphere/${local.environment}"
}

data "aws_caller_identity" "current" {}

# Image Amazon Linux 2023 (AWS CLI incluse) la plus recente
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# --- Reseau : module du registre public, 2 zones, sans NAT Gateway ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = local.subnets

  enable_nat_gateway      = false
  map_public_ip_on_launch = true
}

# --- Secret applicatif : ecriture seule, absent du plan et du state ---
resource "aws_ssm_parameter" "db_password" {
  name             = "${local.secret_path}/db_password"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = 1
}

# --- Politique cible au moindre privilege (documentee) ---
# Le Learner Lab interdit iam:CreateRole : les instances utilisent LabInstanceProfile.
# Sur un compte reel, cette politique serait attachee a un role dedie a l'environnement.
data "aws_iam_policy_document" "read_secrets_target" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter${local.secret_path}/*"]
  }
}

# --- Application : module NovaSphere versionne par tag ---
module "web" {
  source = "git::https://github.com/ordonezhomai/terraform-aws-novasphere-web.git?ref=v1.0.1"

  name                  = local.name
  environment           = local.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnets
  ami_id                = data.aws_ami.al2023.id
  instance_type         = local.instance_type
  instance_profile_name = "LabInstanceProfile"
  secret_parameter_name = aws_ssm_parameter.db_password.name
  min_size              = local.asg_min
  max_size              = local.asg_max
  desired_capacity      = local.asg_min
}
