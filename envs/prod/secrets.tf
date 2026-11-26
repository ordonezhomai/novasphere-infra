# Secret applicatif : ecriture seule. Terraform l'envoie a AWS mais ne le garde
# ni dans le plan ni dans le state. Un secret par environnement.
resource "aws_ssm_parameter" "db_password" {
  #checkov:skip=CKV_AWS_337:Chiffrement par la cle AWS geree (aws/ssm) ; une cle KMS dediee est documentee comme amelioration dans SECURITE.md
  name             = "${local.secret_path}/db_password"
  description      = "Mot de passe applicatif ${var.environment}"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = 1 # incrementer pour pousser une nouvelle valeur (rotation)
}

data "aws_caller_identity" "current" {}

# Politique que l'instance DEVRAIT avoir (moindre privilege).
# Non appliquee : le Learner Lab interdit iam:CreateRole et impose LabInstanceProfile.
data "aws_iam_policy_document" "instance_ideale" {
  statement {
    sid       = "LireLeSecretDeSonEnvironnement"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter${local.secret_path}/*"]
  }

  statement {
    sid       = "DechiffrerAvecLaCleSSM"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.us-east-1.amazonaws.com"]
    }
  }
}
