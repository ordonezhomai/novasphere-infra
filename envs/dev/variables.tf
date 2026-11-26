# Toutes les differences entre dev et prod passent par ces variables.
# Valeurs : terraform.tfvars en local (jamais commite), TF_VAR_* dans la CI.

variable "owner" {
  description = "Trigramme du proprietaire, pose en tag sur toutes les ressources"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{3}$", var.owner))
    error_message = "owner doit etre un trigramme de 3 lettres minuscules."
  }
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit valoir dev ou prod."
  }
}

variable "instance_type" {
  description = "Type des instances web"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "Plage d'adresses du VPC, distincte par environnement"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr doit etre un CIDR valide, ex : 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Zones de disponibilite"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  description = "Subnets publics, un par zone"
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "Il faut au moins deux subnets publics (deux zones)."
  }
}

variable "asg_min_size" {
  description = "Nombre minimal d'instances"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Nombre maximal d'instances"
  type        = number
  default     = 4
}

variable "db_password" {
  description = "Mot de passe applicatif. Fourni uniquement par TF_VAR_db_password, jamais de valeur par defaut"
  type        = string
  sensitive   = true
  ephemeral   = true
}
