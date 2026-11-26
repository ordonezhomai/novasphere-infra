# Fiche de cadrage

> À faire valider par l'intervenant. Les points marqués **[à confirmer]** attendent sa réponse.

## Équipe

| Rôle | Nom |
|---|---|
| Membre | Homa Ordonez |
| Référent Git | Homa Ordonez |
| Référent AWS (son Learner Lab porte toute l'infrastructure) | Homa Ordonez |
| Suppléant | Aucun : équipe d'un membre **[à confirmer]** |

Équipe d'un seul membre **[à confirmer par l'intervenant]**. Conséquence : GitHub interdit d'approuver sa propre
pull request. La protection de `main` exige donc la pull request mais pas d'approbation par un tiers ; l'environnement
`prod` a le membre lui-même comme relecteur requis. Avec un second membre, l'approbation obligatoire serait rétablie.

## Contexte métier

NovaSphere est une startup SaaS. Son application web doit être servie en deux environnements isolés :
`dev`, où l'on teste chaque changement, et `prod`, qui reçoit les utilisateurs. L'équipe d'exploitation
veut une infrastructure reproductible en quelques minutes, résiliente (deux zones, remplacement automatique
des instances), déployée par une chaîne relue et approuvée, sans aucun secret en clair.

## Ce que servent les instances

Une page web servie par nginx sur `/`, qui affiche l'environnement (`NovaSphere - dev` / `NovaSphere - prod`),
le nom du serveur (preuve de la répartition de charge) et « secret chargé : oui » (preuve que l'instance a lu
le mot de passe applicatif dans Parameter Store, sans l'afficher).

## Extension choisie

**Administration sans SSH** : opérations d'administration scriptées par SSM Run Command (`scripts/admin-ssm.sh` :
état, preuve du secret, redémarrage de nginx) et aucune paire de clés dans le code (`aws_key_pair` retiré).
Ce qu'elle exige : agent SSM sur l'instance (inclus dans Amazon Linux 2023), sortie HTTPS vers l'API SSM,
droits SSM du profil d'instance (`LabInstanceProfile`, à vérifier avec `aws ssm describe-instance-information`).

## Ce que l'équipe écarte, et pourquoi

| Écarté | Raison |
|---|---|
| NAT Gateway | Facturée à l'heure, inutile : subnets publics protégés par les SG |
| HTTPS | Pas de domaine dans le lab, certificat autosigné seulement |
| Base RDS, image Packer, Ansible, second service, tests de module | Une seule extension notée ; temps réservé au socle |
| Rôle IAM dédié, fédération OIDC | Refusés par le Learner Lab : documentés dans SECURITE.md et `ci_oidc_compte_classique.tf.exemple` |
