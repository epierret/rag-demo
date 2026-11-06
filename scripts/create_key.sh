#!/usr/bin/env bash
# Crée une clé virtuelle LiteLLM plafonnée à un budget (en USD).
# Usage : set -a; . ./.env; set +a; ./scripts/create_key.sh 5
set -euo pipefail

BUDGET="${1:-5}"
: "${LITELLM_MASTER_KEY:?Definis LITELLM_MASTER_KEY : charge le fichier .env avant}"

curl -sS http://127.0.0.1:4000/key/generate \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"max_budget\": ${BUDGET}, \"models\": [\"mistral-small\"], \"key_alias\": \"demo-rag\"}"
echo
