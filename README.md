# NovaSphere : infrastructure web multi-environnements sur AWS

Infrastructure web NovaSphere en deux environnements (`dev`, `prod`), décrite avec Terraform,
déployée par GitHub Actions, sans aucun secret en clair.

```
Internet ──80──▶ ALB (2 zones) ──80──▶ instances Amazon Linux 2023 (groupe d'auto-scaling, min 2)
                                        └─ lisent leur secret dans Parameter Store au démarrage
```

| Dépôt | Rôle |
|---|---|
| `novasphere-infra` (ce dépôt) | Environnements `envs/dev` et `envs/prod`, CI, documentation |
| [`terraform-aws-novasphere-web`](https://github.com/ordonezhomai/terraform-aws-novasphere-web) | Module de la pile web (SG, Launch Template, ALB, ASG), appelé par tag `v1.1.0` |

Documents : [ARCHITECTURE.md](ARCHITECTURE.md) · [SECURITE.md](SECURITE.md) · [CONTRIBUTING.md](CONTRIBUTING.md) · [CADRAGE.md](CADRAGE.md) · [RESTE_A_FAIRE.md](RESTE_A_FAIRE.md)

---

## 1. Prérequis

| Outil | Version | Vérification |
|---|---|---|
| Terraform | ≥ 1.14 | `terraform version` |
| AWS CLI | 2.x | `aws --version` |
| GitHub CLI | récente | `gh auth status` |
| Git | ≥ 2.30 | `git --version` |

Un accès AWS Academy Learner Lab (région `us-east-1`) et un compte GitHub.

## 2. Identifiants AWS

1. Learner Lab : **Start Lab**, attendre la pastille verte.
2. **AWS Details → AWS CLI → Show**, copier le bloc `[default]` complet (avec `aws_session_token`).
3. Le coller dans `~/.aws/credentials`, puis vérifier :

```bash
aws configure set region us-east-1
aws sts get-caller-identity        # JSON avec Account
```

Les identifiants changent à chaque session (quatre heures). Ils ne vont **jamais** dans un fichier du dépôt.

## 3. Bucket de state (une seule fois)

Le bucket se crée à la CLI : le lab interdit la ressource Terraform `aws_s3_bucket`.

```bash
aws s3api create-bucket --bucket novasphere-tfstate-hor --region us-east-1
aws s3api put-bucket-versioning --bucket novasphere-tfstate-hor --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket novasphere-tfstate-hor \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Pour un autre compte, remplacer le nom du bucket dans `envs/dev/backend.tf` et `envs/prod/backend.tf`.

## 4. Secrets du dépôt GitHub (à chaque Start Lab)

```bash
git clone https://github.com/ordonezhomai/novasphere-infra.git && cd novasphere-infra
gh auth login
export TF_VAR_db_password="$(openssl rand -base64 24)"   # jamais écrit dans un fichier
./scripts/ci-secrets.sh                                  # 4 secrets : AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN, DB_PASSWORD
```

Une seule fois, créer l'environnement GitHub protégé `prod` (relecteur requis) :

```bash
echo '{"reviewers":[{"type":"User","id":'$(gh api user --jq .id)'}]}' \
  | gh api -X PUT repos/ordonezhomai/novasphere-infra/environments/prod --input -
```

## 5. Déployer

### Par la chaîne (méthode normale)

```bash
gh workflow run terraform-apply.yml -f action=apply
```

1. `apply-dev` s'exécute (environ 5 minutes la première fois).
2. `apply-prod` attend : **Actions → le run → Review deployments → prod → Approve and deploy**.

Ensuite, tout changement passe par une pull request : plan posté en commentaire, merge, déploiement automatique.

### En local (diagnostic uniquement)

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars      # ignoré par Git
export TF_VAR_db_password="$(openssl rand -base64 24)"
terraform init
terraform plan
```

## 6. Vérifier

```bash
cd envs/dev && terraform init -input=false > /dev/null
for i in 1 2 3 4; do curl -s "$(terraform output -raw app_url)"; echo; done
```

Résultat attendu : `NovaSphere - dev`, deux noms de serveur qui alternent, `Secret charge depuis Parameter Store : oui`.
Même chose dans `envs/prod` (`NovaSphere - prod`, adresses en `10.1.x`).

Preuve que l'instance a lu le secret, sans l'afficher (extension SSM) :

```bash
./scripts/admin-ssm.sh dev preuve-secret
```

Détection de dérive à la demande :

```bash
gh workflow run terraform-apply.yml -f action=drift
```

## 7. Détruire (après chaque session de travail)

Les ALB sont facturés à l'heure. Le bucket de state est conservé.

```bash
export TF_VAR_db_password="x"     # requis par la variable, valeur sans effet sur un destroy
cd envs/prod && cp -n terraform.tfvars.example terraform.tfvars && terraform init -input=false && terraform destroy
cd ../dev    && cp -n terraform.tfvars.example terraform.tfvars && terraform init -input=false && terraform destroy
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'   # attendu : []
```

Puis **End Lab**.

## 8. Arborescence

```
envs/<env>/
  backend.tf                          clé du state (seule différence entre dev et prod)
  versions.tf                         provider AWS, default_tags
  variables.tf                        owner, environment (validée), instance_type, vpc_cidr, db_password (ephemeral)...
  terraform.tfvars.example            modèle ; terraform.tfvars n'est jamais commité
  main.tf                             AMI, appel du module de l'équipe (ref=v1.1.0)
  network.tf                          module VPC du registre, deux zones, sans NAT Gateway
  secrets.tf                          secret value_wo, politique IAM idéale (documentaire)
  ci_oidc_compte_classique.tf.exemple OIDC GitHub → AWS (documentaire, non appliqué dans le lab)
  outputs.tf                          alb_dns_name, app_url, vpc_id
.github/workflows/
  terraform-pr.yml                    fmt, validate, plan dev + prod posté en commentaire de PR
  terraform-apply.yml                 apply-dev au merge, apply-prod protégé, job drift
scripts/
  ci-secrets.sh                       identifiants du lab vers les secrets du dépôt
  admin-ssm.sh                        extension : administration par SSM Run Command
```
