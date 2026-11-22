output "app_url" {
  description = "URL de l'application (ALB)"
  value       = "http://${module.web.alb_dns_name}"
}

output "alb_dns_name" {
  value = module.web.alb_dns_name
}

output "secret_parameter_name" {
  value = aws_ssm_parameter.db_password.name
}

output "target_least_privilege_policy" {
  description = "Politique cible (non appliquee dans le Learner Lab, voir SECURITE.md)"
  value       = data.aws_iam_policy_document.read_secrets_target.json
}
