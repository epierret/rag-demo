# Monitoring : dépense et CO2 par clé (démo de gouvernance)

Un tableau de bord Grafana, en lecture seule, qui montre :
- la dépense par clé et le budget restant ;
- les clés épuisées ou bloquées (LiteLLM refuse leurs appels) ;
- une estimation du CO2 par modèle, avec la méthode affichée.

Les données viennent de LiteLLM (table de dépenses dans Postgres). Rien n'est exporté ni recopié.

## Mise en place sur la VM

1. Ajoute dans `.env` (voir `.env.example`) :
   - `GRAFANA_ADMIN_PASSWORD` et `GRAFANA_RO_PASSWORD` : `openssl rand -hex 16` pour chacun ;
   - `GRAFANA_IMAGE` : une image Grafana déjà présente sur la VM (`docker images | grep grafana`), pour ne pas télécharger une nouvelle image (le disque est presque plein).

2. Une fois LiteLLM démarré au moins une fois (les tables doivent exister) :

   ```bash
   set -a; . ./.env; set +a
   ./monitoring/setup_monitoring.sh
   ```

   Ce script crée l'utilisateur `grafana_ro` et deux vues. Grafana ne voit que ces vues : ni le texte des conversations, ni les clés.

3. Démarre Grafana. Il n'est pas lancé par `docker compose up -d` : il faut le profil `monitoring`.

   ```bash
   docker compose --profile monitoring up -d grafana
   ```

4. Depuis ton PC, ouvre un tunnel SSH, puis va sur http://127.0.0.1:3100 :

   ```bash
   ssh -L 3100:127.0.0.1:3100 ubuntu@<ip-de-la-vm>
   ```

   Identifiant `admin`, mot de passe `GRAFANA_ADMIN_PASSWORD`. Le dashboard est dans le dossier « Gouvernance IA ».

   Le port 3100 est lié à `127.0.0.1` : il n'est pas exposé sur internet. Ne pas utiliser le port 3000, déjà pris par l'autre stack Grafana de la VM.

## Vérifier que la lecture seule tient

```bash
set -a; . ./.env; set +a

# Doit réussir : les vues
docker compose exec -e PGPASSWORD="$GRAFANA_RO_PASSWORD" postgres \
  psql -h 127.0.0.1 -U grafana_ro -d litellm -c 'SELECT cle, plafond_usd FROM monitoring.v_keys;'

# Doit échouer (permission denied) : la table brute des conversations
docker compose exec -e PGPASSWORD="$GRAFANA_RO_PASSWORD" postgres \
  psql -h 127.0.0.1 -U grafana_ro -d litellm -c 'SELECT * FROM "LiteLLM_SpendLogs" LIMIT 1;'
```

## Méthode CO2 (à présenter comme une estimation)

- **Formule** : CO2 estimé = tokens totaux / 1 000 × facteur du modèle.
- **Facteur `mistral-small`** : 2,85 gCO2e / 1 000 tokens. Il vient de l'analyse de cycle de vie publiée par Mistral AI en 2025 : 1,14 gCO2e pour une réponse de 400 tokens sur Le Chat, inférence marginale seulement. La presse rattache ce chiffre à Mistral Large 2.
- **Ce n'est pas une mesure.** Le chiffre vient d'un modèle plus grand, donc il est probablement haut pour `mistral-small`. Le périmètre exclut les terminaux des utilisateurs. La publication ne dit pas si la fabrication du matériel est incluse, et ne donne pas de marge d'erreur.
- **Biais vers le haut** : la formule compte les tokens d'entrée et de sortie, alors que la référence parle d'une réponse de 400 tokens. L'estimation est donc plutôt haute.
- **Modifier un facteur** : table `monitoring.co2_factors`, sans toucher au dashboard.

## Limites

- Les dépenses sont par clé, pas par personne : AnythingLLM n'envoie qu'une seule clé. Une attribution par personne demande une clé par utilisateur côté LiteLLM.
- Les budgets sont cumulés depuis la création de la clé, pas mensuels.
- Il faut vérifier si les appels refusés par le plafond apparaissent dans les logs de dépense. La démo peut montrer le refus directement dans la réponse de l'API.
- Si Grafana refuse le type de source de données (`grafana-postgresql-datasource`), remplace-le par `postgres` dans `grafana/provisioning/datasources/litellm.yml`.

## À faire ensuite

- Une alerte Grafana à 80 % du budget (le tableau colore déjà la cellule).
- Un second modèle, de raisonnement, pour la comparaison léger / raisonnement. Il faut l'ajouter dans `litellm/config.yaml` et l'autoriser dans la clé.
