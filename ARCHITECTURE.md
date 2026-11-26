# Architecture et décisions

## Schéma

```
                         GitHub : novasphere-infra
   PR ──▶ terraform-pr.yml : fmt -check, validate, plan dev + prod ──▶ commentaire de PR
   merge sur main ──▶ terraform-apply.yml : apply-dev (fichier de plan) ──▶ [approbation] ──▶ apply-prod
   nuit / manuel  ──▶ terraform-apply.yml : drift (plan -detailed-exitcode)
                               │ identifiants de session du lab (secrets du dépôt)
                               ▼
 AWS us-east-1 (Learner Lab)
 ┌─ S3 novasphere-tfstate-hor (versionné, chiffré, use_lockfile) ─ novasphere/dev/… │ novasphere/prod/… ─┐
 │                                                                                                      │
 │  envs/dev : VPC 10.0.0.0/16                       envs/prod : VPC 10.1.0.0/16 (même code)            │
 │  ┌──────────────────────────────────────────┐     ┌──────────────────────────────────────────┐       │
 │  │ subnet public us-east-1a │ subnet 1b      │     │ subnet public us-east-1a │ subnet 1b      │       │
 │  │      [ ALB ]  SG alb : 80 depuis Internet│     │      [ ALB ]                              │       │
 │  │        │ 80                               │     │        │                                  │       │
 │  │  [ ASG min 2 ] SG web : 80 depuis SG alb │     │  [ ASG min 2, t3.small ]                  │       │
 │  │   AL2023, IMDSv2, disque chiffré, pas SSH│     │                                           │       │
 │  └──────────────────────────────────────────┘     └──────────────────────────────────────────┘       │
 │  Parameter Store : /novasphere/dev/db_password      /novasphere/prod/db_password (SecureString)     │
 └──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Au démarrage, chaque instance reçoit par `templatefile` le **nom** de son environnement et le **chemin**
de son secret, lit le secret avec son profil d'instance, l'écrit dans `/etc/novasphere/app.conf` (0640)
et sert une page qui indique l'environnement et « secret chargé : oui ».

## Décisions et alternatives écartées

| Sujet | Décision | Alternative écartée, et pourquoi |
|---|---|---|
| Séparation des environnements | Répertoires `envs/dev` et `envs/prod`, une clé de state chacun | Workspaces : environnement courant invisible, même commande `destroy` partout, refusés par le cahier des charges |
| Différences dev / prod | Uniquement par variables : `terraform.tfvars` en local (non commité), `TF_VAR_*` dans la CI. Le code des deux dossiers est identique, seule la clé de `backend.tf` change | Valeurs dans des `locals` propres à chaque dossier : deux dossiers qui divergent dans le code, défaut relevé par le cahier des charges (première version de la maquette, corrigée) |
| Pile web | Module de l'équipe dans son propre dépôt public, appelé par tag `v1.1.0` par les deux environnements | Module local : ni partagé ni versionné. Copier-coller dev → prod : deux corrections à faire au lieu d'une |
| Réseau | Module VPC du registre public, deux zones, subnets publics, **sans NAT Gateway** | NAT Gateway (≈ 0,05 $/h + trafic) : inutile, les instances sortent par l'Internet Gateway, protégées par leurs SG |
| Image | Amazon Linux 2023 | Debian (starter) : AWS CLI absente, l'amorçage aurait dû l'installer et dépasser dix lignes |
| Amorçage | `bootstrap.sh` de 9 lignes passé par `templatefile` | Ansible au démarrage ou image Packer : plus lourds, hors socle. Le dossier Ansible du starter a été retiré |
| Accès aux instances | Port 80 depuis le SG de l'ALB uniquement (référence de SG), aucun SSH, aucune paire de clés | SSH restreint à une IP : surface d'attaque inutile, l'administration passe par SSM (extension) |
| Sortie des instances | HTTPS 443 seulement | Tout autoriser (version v1.0.1 du module) : relevé par checkov, corrigé en v1.1.0 |
| Règles de SG | Ressources séparées `aws_vpc_security_group_*_rule` | Blocs `ingress`/`egress` en ligne : dépendance circulaire dès que les deux SG se référencent |
| Secret | Parameter Store `SecureString`, `value_wo` + `value_wo_version`, variable `ephemeral` | `value` classique : le secret finirait dans le state. Secrets Manager : rotation inutile ici, ≈ 0,40 $/secret/mois |
| Profil des instances | `LabInstanceProfile` (imposé) ; politique idéale écrite dans `secrets.tf` et `SECURITE.md` | Rôle dédié au moindre privilège : `iam:CreateRole` refusé dans le lab |
| Authentification de la CI | Identifiants de session du lab en secrets du dépôt, rafraîchis par `scripts/ci-secrets.sh` | OIDC : création du fournisseur refusée dans le lab. Écrit dans `ci_oidc_compte_classique.tf.exemple` |
| Déploiement | Apply du **fichier de plan** (`apply tfplan`), dev automatique au merge, prod derrière l'environnement GitHub `prod` | Apply d'un nouveau plan : ce qui est déployé pourrait différer de ce qui a été relu |
| Visibilité du dépôt | Public, après vérification de l'historique (aucun secret) | Privé : la protection d'environnement (relecteur requis) n'est pas disponible sur un compte GitHub gratuit |
| Dérive | Job `drift` dans `terraform-apply.yml`, planifié la nuit et déclenchable à la main | — |

## Extension choisie : administration sans SSH

`scripts/admin-ssm.sh` envoie une commande par **SSM Run Command** à toutes les instances d'un environnement
(ciblage par tags) : état de nginx, preuve que le secret est présent (droits, taille, empreinte tronquée
`sha256sum | cut -c1-8`, jamais la valeur), redémarrage de nginx. Aucun port 22, aucune `aws_key_pair` dans le code.

Extensions écartées : HTTPS (pas de domaine, certificat autosigné seulement), RDS (temps et coût),
Packer, Ansible, second service, tests de module (temps).

## Journal des décisions d'exploitation

| Date | Événement | Décision |
|---|---|---|
| 22/11 | Dérive : port 8080 ouvert à la main sur le SG web de dev, détectée par le job `drift` | **Le code a raison** : rien ne justifie d'exposer 8080. Remédiation par apply via la CI, job `drift` revenu au vert |
| 22/11 | AWS refuse l'apostrophe dans une description de SG | Correctif publié en `v1.0.1`, nouveau tag (un tag publié n'est jamais modifié) |
| 22/11 | YAML de workflow invalide (« : » dans une valeur non quotée) | Corrigé par PR ; un run en échec en 0 s nommé par son chemin signale un fichier invalide |
| 26/11 | Lecture du cahier des charges : dev et prod différaient dans le code | Refonte : différences portées par les variables, module `v1.1.0` |
