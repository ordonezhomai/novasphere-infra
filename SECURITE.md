# Sécurité

## 1. Les secrets et où ils vivent

| Secret | Où il vit | Où il ne doit jamais être | Comment c'est garanti |
|---|---|---|---|
| Mot de passe applicatif `db_password` | Parameter Store, `SecureString` chiffré KMS (clé `aws/ssm`) : `/novasphere/dev/db_password` et `/novasphere/prod/db_password` | Code, tfvars, state, plan, `user_data`, historique Git, logs de CI | Variable `ephemeral` + `sensitive`, sans valeur par défaut ; ressource en **écriture seule** (`value_wo`, `value_wo_version`) ; valeur fournie par `TF_VAR_db_password` (terminal) ou le secret GitHub `DB_PASSWORD` (CI) |
| Identifiants AWS du poste | `~/.aws/credentials` du référent | Tout fichier du dépôt | `.gitignore`, aucune commande ne les affiche |
| Identifiants AWS de la CI | Secrets du dépôt `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Code, logs | Identifiants de **session** (expirent en quatre heures), copiés par `scripts/ci-secrets.sh` via l'entrée standard ; GitHub les masque dans les logs |
| State Terraform | S3 `novasphere-tfstate-hor`, versionné, chiffré, verrouillé | Dépôt Git | `.gitignore` (`*.tfstate*`), backend S3 dès le premier commit |

Ce qui transite vers l'instance : le **nom** de l'environnement et le **chemin** du secret, par `templatefile`.
L'instance lit la valeur elle-même au démarrage, avec son profil d'instance, et l'écrit dans
`/etc/novasphere/app.conf` (droits 0640). La page affiche « secret chargé : oui », jamais la valeur.

### Preuves (à rejouer en soutenance)

```bash
cd envs/dev
terraform state pull | grep -c -- "$TF_VAR_db_password"                     # 0 : absent du state
git log -p --all | grep -c -- "$TF_VAR_db_password"                         # 0 : absent de l'historique
LT=$(aws ec2 describe-launch-templates --filters Name=tag:Environment,Values=dev --query 'LaunchTemplates[0].LaunchTemplateName' --output text)
aws ec2 describe-launch-template-versions --launch-template-name "$LT" --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData.UserData' --output text | base64 -d | grep -c -- "$TF_VAR_db_password"   # 0
aws ec2 describe-instances --filters Name=tag:Environment,Values=dev Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].MetadataOptions.HttpTokens'           # "required" : IMDSv2
../../scripts/admin-ssm.sh dev preuve-secret                                # fichier présent, empreinte tronquée
```

Relevé du 22/11 sur dev : state **0**, historique Git **0**, `user_data` **0**, IMDSv2 **required** sur les deux instances,
SG des instances : port 80 avec pour seule source le SG de l'ALB, aucun CIDR.

Historique du dépôt vérifié avant de le rendre public :
`git log -p --all | grep -iE 'aws_secret_access_key|aws_session_token *=|BEGIN .*PRIVATE KEY'`
ne renvoie que des **noms** de paramètres (`secrets.AWS_SECRET_ACCESS_KEY`, `aws configure get aws_secret_access_key`), aucune valeur.

## 2. Politique IAM que l'instance devrait avoir

Le Learner Lab refuse `iam:CreateRole` : les instances utilisent `LabInstanceProfile`, beaucoup plus large que nécessaire.
Sur un compte classique, chaque environnement aurait son rôle avec cette seule politique (générée par
`data.aws_iam_policy_document.instance_ideale`, visible avec `terraform output politique_instance_ideale`) :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LireLeSecretDeSonEnvironnement",
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "arn:aws:ssm:us-east-1:<compte>:parameter/novasphere/dev/*"
    },
    {
      "Sid": "DechiffrerAvecLaCleSSM",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "*",
      "Condition": { "StringEquals": { "kms:ViaService": "ssm.us-east-1.amazonaws.com" } }
    }
  ]
}
```

Avec cette politique, une instance de dev obtiendrait `AccessDeniedException` sur `/novasphere/prod/…` :
un secret de dev ne peut pas être lu par la prod, ni l'inverse. Pour l'extension SSM, on ajouterait la politique
gérée `AmazonSSMManagedInstanceCore`. **Écart assumé, imposé par le lab** : avec `LabInstanceProfile`, cette
isolation repose seulement sur le code (chaque instance ne lit que le chemin de son environnement).

## 3. Écart OIDC

| | Learner Lab (appliqué) | Compte classique (cible) |
|---|---|---|
| Authentification | Identifiants de session du référent en secrets du dépôt | Fédération OIDC GitHub → AWS (`sts:AssumeRoleWithWebIdentity`) |
| Durée de vie | Quatre heures, renouvelés à chaque Start Lab par `scripts/ci-secrets.sh` | Une heure, émis à chaque exécution |
| Secret stocké dans GitHub | Oui (temporaire) | **Aucun** |
| Restriction | Tous les droits du lab | Rôle par environnement, limité à ce dépôt (`sub`) et à l'environnement GitHub `prod` pour la prod |

Code de la cible : `envs/*/ci_oidc_compte_classique.tf.exemple` (non lu par Terraform, extension `.exemple`).

Conséquences acceptées : le job `drift` planifié la nuit échoue sur l'authentification quand la session du lab
est fermée (il se déclenche à la main pendant une session) ; tout collaborateur pourrait lire les identifiants
en modifiant un workflow dans sa branche, d'où : seuls les membres et l'intervenant sont collaborateurs,
`permissions:` minimales, jamais `pull_request_target`.

## 4. Scan de sécurité : checkov

Commandes (checkov 3.4) :

```bash
checkov -d ../terraform-aws-novasphere-web --framework terraform --compact
checkov -d envs/dev  --framework terraform --compact --download-external-modules true
checkov -d envs/prod --framework terraform --compact --download-external-modules true
```

### Résultats

| Périmètre | Avant (module v1.0.1) | Après (module v1.1.0) |
|---|---|---|
| Module de l'équipe | 21 réussis, **11 échecs** | 37 réussis, **0 échec**, 9 exceptions justifiées |
| `envs/dev`, `envs/prod` (hors modules externes) | — | 16 réussis, **0 échec**, 3 exceptions justifiées |

### Corrigés

| Règle | Ressource | Correction |
|---|---|---|
| `CKV_AWS_382` sortie vers 0.0.0.0/0 sur tous les ports | SG de l'ALB | Sortie limitée au port 80 **vers le SG des instances** |
| `CKV_AWS_382` sortie vers 0.0.0.0/0 sur tous les ports | SG des instances | Sortie limitée à **HTTPS 443** (dépôts de paquets, API SSM) |
| (durcissement) disque racine non chiffré | Launch Template | `block_device_mappings` avec `encrypted = true` |

### Documentés et non corrigés (commentaire `#checkov:skip` sur la ressource)

| Règle | Ressource | Justification |
|---|---|---|
| `CKV_AWS_2`, `CKV_AWS_103`, `CKV2_AWS_20`, `CKV_AWS_378` | listener, ALB, target group | Pas de HTTPS : le lab ne fournit ni domaine ni certificat de confiance. Sur un compte réel : certificat ACM, listener 443, redirection 80 → 443 |
| `CKV_AWS_260` | règle d'entrée de l'ALB | L'ALB est le point d'entrée public de l'application : le port 80 ouvert à Internet est voulu, et c'est la seule ouverture |
| `CKV_AWS_260` | règle d'entrée des instances | **Faux positif** : la source est le SG de l'ALB (`referenced_security_group_id`), aucun CIDR |
| `CKV_AWS_150` | ALB | Protection contre la suppression désactivée : l'infrastructure est détruite après chaque session de lab |
| `CKV_AWS_91` | ALB | Journaux d'accès non activés : ils exigent un bucket S3 géré par Terraform, interdit dans le cadre du lab |
| `CKV2_AWS_28` | ALB | Pas de WAF : hors périmètre du projet |
| `CKV_AWS_337` | `aws_ssm_parameter` | Chiffrement par la clé gérée `aws/ssm`. Amélioration : clé KMS dédiée par environnement |
| `CKV_TF_1` | appels de modules | Le cahier des charges impose un appel par **tag** (`ref=vX.Y.Z`, jamais modifié) plutôt que par hash de commit ; le module VPC est épinglé par version et figé par `.terraform.lock.hcl` |

Les résultats remontés par checkov à l'intérieur du **module VPC du registre** (journaux de flux VPC, etc.)
relèvent du module public et ne sont pas modifiés ici. Amélioration possible : journaux de flux VPC,
qui exigent un rôle IAM (interdit dans le lab).

## 5. Autres mesures

- **IMDSv2 exigé** (`http_tokens = "required"`, `hop_limit = 1`) : un vol du jeton de métadonnées par SSRF devient beaucoup plus difficile.
- **Aucun port SSH**, aucune paire de clés : l'administration passe par SSM Run Command (`scripts/admin-ssm.sh`).
- **Security Groups chaînés** : les instances ne sont joignables que par l'ALB.
- **CI** : `permissions:` minimales par workflow, apply du fichier de plan relu, prod derrière une approbation, `concurrency` pour éviter deux déploiements simultanés.
- **Dépôt** : `.gitignore` excluant state, tfvars, clés, `.env` et cache ; `main` protégée (pull request obligatoire, pas de force-push, règle appliquée aussi au propriétaire).
