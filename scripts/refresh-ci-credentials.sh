#!/usr/bin/env bash
# Learner Lab : pas d'OIDC possible (iam:CreateRole refuse).
# Copie les identifiants TEMPORAIRES de la session (expirent avec le lab) vers les secrets GitHub.
# Aucune valeur n'est affichee ni ecrite dans un fichier. A relancer a chaque session du lab.
set -euo pipefail
aws configure get aws_access_key_id     | gh secret set AWS_ACCESS_KEY_ID
aws configure get aws_secret_access_key | gh secret set AWS_SECRET_ACCESS_KEY
aws configure get aws_session_token     | gh secret set AWS_SESSION_TOKEN
if [ -n "${TF_VAR_db_password:-}" ]; then printf %s "$TF_VAR_db_password" | gh secret set DB_PASSWORD; fi
gh secret list
