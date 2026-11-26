locals {
  name        = "novasphere-${var.environment}"
  secret_path = "/novasphere/${var.environment}"
}

# Amazon Linux 2023 : AWS CLI incluse, le secret se lit en une ligne au demarrage
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# La pile web : module de l'equipe, meme tag pour dev et prod
module "web" {
  #checkov:skip=CKV_TF_1:Le cahier des charges impose un appel par tag (ref=vX.Y.Z), jamais modifie apres publication
  source = "git::https://github.com/ordonezhomai/terraform-aws-novasphere-web.git?ref=v1.1.0"

  name                  = local.name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnets
  ami_id                = data.aws_ami.al2023.id
  instance_type         = var.instance_type
  instance_profile_name = "LabInstanceProfile" # impose par le Learner Lab, voir SECURITE.md
  secret_parameter_name = aws_ssm_parameter.db_password.name
  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  desired_capacity      = var.asg_min_size
}
