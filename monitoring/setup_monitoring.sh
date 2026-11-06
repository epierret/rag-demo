#!/usr/bin/env bash
# Prépare Postgres pour Grafana : utilisateur grafana_ro et vues en lecture seule.
# À lancer une fois, après le premier démarrage de LiteLLM (les tables doivent exister).
set -euo pipefail
cd "$(dirname "$0")/.."

set -a; . ./.env; set +a
: "${GRAFANA_RO_PASSWORD:?Définis GRAFANA_RO_PASSWORD dans .env}"
if [ "$GRAFANA_RO_PASSWORD" = "change-me" ]; then
  echo "Remplace la valeur par défaut de GRAFANA_RO_PASSWORD dans .env" >&2
  exit 1
fi

docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -v "pwd=${GRAFANA_RO_PASSWORD}" \
  -U litellm -d litellm -f - < monitoring/sql/setup.sql

echo "OK : utilisateur grafana_ro et vues monitoring.v_spend / monitoring.v_keys prêts."
