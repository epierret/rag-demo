#!/usr/bin/env bash
# Crée une clé virtuelle LiteLLM plafonnée à un budget (en USD).
# Usage : set -a; . ./.env; set +a; ./scripts/create_key.sh [budget_usd] [alias]
# Exemples : ./scripts/create_key.sh 5 cle-standard   |   ./scripts/create_key.sh 1 cle-avancee
set -euo pipefail

BUDGET="${1:-5}"
ALIAS="${2:-demo-rag}"
: "${LITELLM_MASTER_KEY:?Definis LITELLM_MASTER_KEY : charge le fichier .env avant}"

if ! [[ "$BUDGET" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Budget invalide : un nombre positif, par exemple 5 ou 0.5" >&2
  exit 1
fi
if ! [[ "$ALIAS" =~ ^[a-z0-9-]+$ ]]; then
  echo "Alias invalide : minuscules, chiffres et tirets seulement" >&2
  exit 1
fi

curl -sS http://127.0.0.1:4000/key/generate \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"max_budget\": ${BUDGET}, \"models\": [\"mistral-small\"], \"key_alias\": \"${ALIAS}\"}"
echo
