#!/usr/bin/env bash
# Copie les identifiants de SESSION du Learner Lab du referent AWS vers les secrets du depot.
# A relancer a chaque Start Lab et avant la soutenance (identifiants valables 4 heures).
# Aucune valeur n'est affichee ni ecrite dans un fichier : tout passe par l'entree standard.
set -euo pipefail

aws sts get-caller-identity --query Arn --output text > /dev/null \
  || { echo "Identifiants AWS invalides : recolle ~/.aws/credentials depuis AWS Details" >&2; exit 1; }

aws configure get aws_access_key_id     | gh secret set AWS_ACCESS_KEY_ID
aws configure get aws_secret_access_key | gh secret set AWS_SECRET_ACCESS_KEY
aws configure get aws_session_token     | gh secret set AWS_SESSION_TOKEN

# Mot de passe applicatif : seulement s'il est exporte dans ce terminal.
# Apres le premier deploiement, sa valeur n'est relue que si value_wo_version change.
if [ -n "${TF_VAR_db_password:-}" ]; then
  printf %s "$TF_VAR_db_password" | gh secret set DB_PASSWORD
fi

gh secret list
