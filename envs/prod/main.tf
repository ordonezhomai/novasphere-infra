# Valeurs de l environnement prod : versionnees, relues en PR, aucun secret ici.
locals {
  environment   = "prod"
  name          = "novasphere-${local.environment}"
  instance_type = "t3.micro"
  asg_min       = 2
  asg_max       = 4
}
