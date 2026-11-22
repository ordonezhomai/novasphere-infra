variable "db_password" {
  description = "Mot de passe applicatif, fourni uniquement par TF_VAR_db_password"
  type        = string
  sensitive   = true
  ephemeral   = true
}
