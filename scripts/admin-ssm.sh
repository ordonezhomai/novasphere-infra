#!/usr/bin/env bash
# Extension « Administration sans SSH » : operations d'administration par SSM Run Command.
# Aucun port SSH ouvert, aucune paire de cles dans le code.
#
# Usage : ./scripts/admin-ssm.sh <dev|prod> <etat|preuve-secret|redemarrer>
#   etat           nginx actif ? sur quelles instances ?
#   preuve-secret  le fichier du secret existe : droits, proprietaire, taille, empreinte tronquee
#                  (jamais la valeur, conforme au cahier des charges)
#   redemarrer     redemarre nginx sur toutes les instances de l'environnement
set -euo pipefail

ENV="${1:-}"; ACTION="${2:-etat}"
case "$ENV" in dev|prod) ;; *) echo "Usage : $0 <dev|prod> <etat|preuve-secret|redemarrer>" >&2; exit 1 ;; esac

case "$ACTION" in
  etat)          CMD='echo "$(hostname) nginx=$(systemctl is-active nginx)"' ;;
  preuve-secret) CMD='stat -c "%n droits=%a proprio=%U:%G taille=%s octets" /etc/novasphere/app.conf; echo "empreinte=$(sha256sum /etc/novasphere/app.conf | cut -c1-8)"' ;;
  redemarrer)    CMD='systemctl restart nginx; echo "$(hostname) nginx=$(systemctl is-active nginx)"' ;;
  *) echo "Action inconnue : $ACTION (etat | preuve-secret | redemarrer)" >&2; exit 1 ;;
esac

PARAMS=$(python3 -c 'import json,sys; print(json.dumps({"commands": [sys.argv[1]]}))' "$CMD")

ID=$(aws ssm send-command --region us-east-1 \
  --document-name AWS-RunShellScript \
  --targets "Key=tag:Project,Values=NovaSphere" "Key=tag:Environment,Values=$ENV" \
  --comment "novasphere $ENV $ACTION" \
  --parameters "$PARAMS" \
  --query Command.CommandId --output text)
echo "Commande SSM $ID envoyee aux instances $ENV ($ACTION)"

for _ in $(seq 1 30); do
  STATUS=$(aws ssm list-commands --region us-east-1 --command-id "$ID" --query 'Commands[0].Status' --output text)
  case "$STATUS" in Pending|InProgress) sleep 2 ;; *) break ;; esac
done
echo "Statut : $STATUS"

aws ssm list-command-invocations --region us-east-1 --command-id "$ID" --details \
  --query 'CommandInvocations[].[InstanceId,Status,CommandPlugins[0].Output]' --output text
