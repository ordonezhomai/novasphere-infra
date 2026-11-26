output "alb_dns_name" {
  description = "Nom DNS de l'ALB"
  value       = module.web.alb_dns_name
}

output "app_url" {
  description = "URL de l'application"
  value       = "http://${module.web.alb_dns_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "asg_name" {
  value = module.web.asg_name
}

output "secret_parameter_name" {
  description = "Chemin du secret (le chemin, jamais la valeur)"
  value       = aws_ssm_parameter.db_password.name
}

output "politique_instance_ideale" {
  description = "Politique IAM au moindre privilege (documentaire, voir SECURITE.md)"
  value       = data.aws_iam_policy_document.instance_ideale.json
}
