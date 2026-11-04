# Conventions d'equipe NovaSphere

1. Une branche par changement, jamais de commit direct sur main.
2. Toute modification passe par une pull request relue par l'autre membre avant merge.
3. Le plan Terraform est lu en entier avant tout apply.
4. Un tag par seance : v5.<seance>.0.
5. Le state vit uniquement dans s3://novasphere-tfstate-hor, verrouille par use_lockfile.
6. dynamodb_table est deprecie par HashiCorp : on utilise use_lockfile.
7. Jamais de force-unlock sans accord explicite de l'equipe.
8. Le .gitignore n'est jamais allege : *.tfstate, *.tfvars, *.pem, .env, inventaires generes.
9. Aucun secret dans le code, les commits ou les logs.
10. Fin de journee : terraform destroy ou scripts/stop-evening.sh, sans exception.
