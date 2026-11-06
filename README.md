# rag-demo : RAG juridique de démo (corpus public uniquement)

Chaîne : **AnythingLLM** (interface et RAG) → **LiteLLM** (passerelle, clés, plafonds) → **API Mistral** (hébergée en UE).
Postgres stocke les clés LiteLLM.

> Démo uniquement. Corpus public : aucune pièce réelle de client tant qu'il n'y a pas de cadre contractuel (RGPD, sous-traitance).

## 0. Prérequis sur la VM

- Docker et le plugin Compose : `docker compose version`
- Une clé API Mistral, avec une **limite de dépense mensuelle** activée dans la console Mistral (filet de sécurité indépendant de LiteLLM)
- `cloudflared` pour le lien public temporaire (voir section 6)

## 1. Installation

```bash
git clone <URL_DU_REPO> rag-demo      # ou dézippe l'archive
cd rag-demo
cp .env.example .env
```

Édite `.env` :
- `MISTRAL_API_KEY` : ta clé Mistral
- `LITELLM_MASTER_KEY` : `openssl rand -hex 24`, avec le préfixe `sk-`
- `POSTGRES_PASSWORD` : `openssl rand -hex 16`

Démarre la stack :

```bash
docker compose up -d
docker compose ps          # les trois services doivent être "running"
docker compose logs -f litellm   # attends "Uvicorn running" ou équivalent, Ctrl+C pour sortir
```

## 2. Créer la clé de démo plafonnée

```bash
set -a; . ./.env; set +a
chmod +x scripts/create_key.sh
./scripts/create_key.sh 5        # plafond de 5 USD
```

La réponse contient la clé virtuelle (`"key": "sk-..."`). Garde-la pour l'étape 3.

Le plafond est en USD et le budget est total, pas mensuel. Ajuste le montant selon ce que tu acceptes de perdre.

## 3. Configurer AnythingLLM (une seule fois)

Ouvre `http://127.0.0.1:3001` sur la VM. Si tu y accèdes depuis ton PC, passe par un tunnel SSH : `ssh -L 3001:127.0.0.1:3001 ubuntu@<ip-de-la-vm>`.

1. Crée le compte administrateur.
2. **Modèle LLM** : choisis le fournisseur compatible OpenAI (« Generic OpenAI » ou équivalent selon ta version).
   - URL de base : `http://litellm:4000/v1` (le nom `litellm` ne fonctionne qu'à l'intérieur du réseau Docker, c'est voulu)
   - Clé : la clé virtuelle de l'étape 2
   - Modèle : `mistral-small`
3. **Embeddings** : laisse le moteur natif pour la démo. Il tourne en local, sans API. Sa qualité sur le français juridique est limitée : c'est une amélioration à prévoir ensuite.
4. **Base vectorielle** : laisse la valeur par défaut.
5. **Multi-utilisateurs** : active le mode multi-utilisateur dans les paramètres, puis crée un compte par personne. Pas d'accès anonyme.

Vérifie chaque réglage à la première ouverture : l'emplacement exact des options dépend de la version d'AnythingLLM.

## 4. Charger le corpus public

- Récupère les articles utiles sur Légifrance (Code civil, Code du travail) : quelques dizaines à quelques centaines d'articles suffisent pour la démo, pas le code entier.
- Enregistre-les en `.txt` ou `.pdf`, un fichier par code ou par thème.
- Dans AnythingLLM : crée un espace « Code civil » et importe les fichiers, puis lance l'indexation.

## 5. Tester

Ouvre `scripts/questions_test.md` et pose chaque question. Pour chacune, vérifie :
- la réponse est juste ;
- la source citée est la bonne ;
- le système refuse quand l'information n'est pas dans le corpus (question 5 : le test le plus important).

Vérifie chaque numéro d'article sur Légifrance avant la démo.

## 6. Lien public temporaire

```bash
cloudflared tunnel --url http://localhost:3001
```

La commande affiche une URL `https://....trycloudflare.com`. Elle change à chaque lancement.

**Avant de la donner à qui que ce soit :**
- ouvre l'URL depuis ton téléphone en 4G ;
- connecte-toi avec un compte de test ;
- vérifie qu'une question hors corpus est bien refusée.

Ce tunnel de test n'a aucune garantie de disponibilité. Évite de redémarrer la VM pendant la démo.

## 7. Checklist avant de partager

- [ ] Plafond de dépense créé avec `create_key.sh`
- [ ] Limite de dépense mensuelle active dans la console Mistral
- [ ] Mode multi-utilisateur activé, aucun accès anonyme
- [ ] Corpus public uniquement
- [ ] Ports liés à `127.0.0.1` (rien n'est exposé directement)
- [ ] Test depuis la 4G réussi
- [ ] Conditions d'utilisation de la plateforme de formation vérifiées

## 8. Couper l'accès

```bash
# arrêter le lien public : Ctrl+C dans le terminal de cloudflared
docker compose stop         # arrête la stack, les données restent dans ./data
```

Pour révoquer la clé de démo, supprime-la dans LiteLLM (endpoint `/key/delete`) ou change la clé maître.

## Dépannage

- Un service ne démarre pas : `docker compose logs <service>`
- AnythingLLM ne voit pas le modèle : vérifie l'URL `http://litellm:4000/v1` et la clé virtuelle, puis `docker compose logs -f litellm`
- Erreurs d'authentification Mistral : vérifie `MISTRAL_API_KEY` dans `.env`, puis relance `docker compose up -d`

## Limites connues

- **Une seule clé pour AnythingLLM** : LiteLLM voit une clé, pas la personne qui pose la question. Le plafond est donc global à la démo. Une gouvernance par personne demande une clé par utilisateur côté passerelle, ce qui n'est pas dans cette version.
- Les embeddings natifs sont faibles en français. Pour une version plus sérieuse, passe par un modèle d'embeddings multilingue (bge-m3 ou un endpoint hébergé en UE).
- Non testé sur ta VM au moment de l'écriture : les noms des options AnythingLLM et les détails de l'endpoint LiteLLM sont à valider au premier démarrage.
