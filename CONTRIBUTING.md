# Conventions d'équipe NovaSphere

Règles de la séance 1, adaptées au projet. Elles s'appliquent à tout changement.

1. **Une branche par changement**, jamais de commit direct sur `main` (branche protégée).
2. **Toute modification passe par une pull request.** La CI y poste le plan de dev et de prod : il se lit en entier avant le merge.
3. **Relecture** : chaque PR est relue par un autre membre (GitHub interdit d'approuver sa propre PR). Équipe d'un membre : voir CADRAGE.md.
4. **Aucun apply à la main** sur dev ou prod : le déploiement se fait par la CI au merge, prod après approbation dans l'environnement GitHub `prod`. Seules exceptions, sur le poste du référent AWS : destruction de fin de session et diagnostic.
5. **Un tag par livraison** : le module est versionné `vX.Y.Z` (un tag publié n'est jamais modifié) ; le dépôt est gelé par le tag `rendu-final`.
6. **Le state** vit uniquement dans `s3://novasphere-tfstate-hor`, une clé par environnement, verrouillé par `use_lockfile` (`dynamodb_table` est déprécié).
7. **Jamais de `force-unlock`** sans avoir vérifié avec l'équipe que personne n'a d'opération en cours.
8. **Le `.gitignore` n'est jamais allégé** : `*.tfstate*`, `*.tfvars`, `*.pem`, `.env`, `.terraform/`, inventaires générés.
9. **Aucun secret** dans le code, les tfvars, les commits, les commentaires de PR ni les logs. Le mot de passe passe par `TF_VAR_db_password` ou le secret GitHub `DB_PASSWORD`.
10. **Dev et prod ne diffèrent que par les variables** (et la clé de `backend.tf`) : un changement de code s'applique aux deux.
11. **À chaque Start Lab** : `./scripts/ci-secrets.sh`. **Avant de quitter** : `terraform destroy` de prod puis de dev, vérification qu'aucun ALB ne reste, End Lab.
12. **Collaborateurs** : seulement les membres de l'équipe et l'intervenant ; jamais `pull_request_target`, `permissions:` minimales.

## Réglages GitHub appliqués

- Dépôt public, travail par branches (pas de fork : un workflow lancé depuis un fork ne reçoit pas les secrets).
- Protection de `main` : pull request obligatoire, approbations annulées par un nouveau push, pas de force-push ni de suppression, règle appliquée aussi aux administrateurs.
- Environnement `prod` : relecteur requis.
