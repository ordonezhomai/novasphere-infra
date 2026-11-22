# Valeurs de l'environnement dev : versionnees, relues en PR, aucun secret ici.
locals {
  environment   = "dev"
  name          = "novasphere-${local.environment}"
  instance_type = "t3.micro"
  asg_min       = 2
  asg_max       = 4
}
