-- Vues en lecture seule pour Grafana, et facteurs d'estimation CO2.
-- À exécuter après le premier démarrage de LiteLLM (les tables existent alors).
-- Lancé par monitoring/setup_monitoring.sh, qui fournit le mot de passe via la variable psql :pwd.
-- Les vues ne contiennent ni le texte des conversations ni les clés (hachées ou non).

CREATE SCHEMA IF NOT EXISTS monitoring;

-- Facteurs d'estimation CO2 : modifiables ici, sans toucher au dashboard.
CREATE TABLE IF NOT EXISTS monitoring.co2_factors (
    model               text PRIMARY KEY,
    gco2_per_1k_tokens  numeric NOT NULL,
    source              text NOT NULL,
    incertitude         text NOT NULL
);

INSERT INTO monitoring.co2_factors (model, gco2_per_1k_tokens, source, incertitude)
VALUES (
    'mistral-small',
    2.85,
    'Mistral AI, analyse de cycle de vie (2025) : 1,14 gCO2e pour une réponse de 400 tokens sur Le Chat, inférence marginale. Chiffre rapporté pour Mistral Large 2, soit 2,85 g / 1 000 tokens',
    'Probablement haute : chiffre d''un modèle plus grand, non mesuré pour mistral-small. Périmètre : inférence marginale, hors terminaux'
)
ON CONFLICT (model) DO NOTHING;

-- Utilisateur de lecture seule : il ne peut lire que les vues ci-dessous,
-- pas les tables LiteLLM (qui contiennent le texte des conversations).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grafana_ro') THEN
        CREATE ROLE grafana_ro LOGIN;
    END IF;
END
$$;
ALTER ROLE grafana_ro LOGIN PASSWORD :'pwd';

-- Dépense et CO2 par appel.
-- Le nom du modèle public (model_group, p. ex. « mistral-small ») est prioritaire :
-- c'est lui qui correspond à la table de facteurs. Repli sur model si model_group est vide.
CREATE OR REPLACE VIEW monitoring.v_spend AS
SELECT
    s."startTime"                                                       AS ts,
    COALESCE(NULLIF(s.model_group, ''), s.model)                        AS model,
    COALESCE(t.key_alias, 'sans alias')                                 AS cle,
    s.spend                                                             AS cout_usd,
    s.prompt_tokens                                                     AS tokens_entree,
    s.completion_tokens                                                 AS tokens_sortie,
    s.total_tokens                                                      AS tokens_total,
    ROUND(s.total_tokens / 1000.0 * COALESCE(f.gco2_per_1k_tokens, 0), 4) AS co2_g_estime,
    (f.model IS NULL)                                                   AS facteur_manquant
FROM "LiteLLM_SpendLogs" s
LEFT JOIN "LiteLLM_VerificationToken" t ON t.token = s.api_key
LEFT JOIN monitoring.co2_factors f ON f.model = COALESCE(NULLIF(s.model_group, ''), s.model);

-- Budget par clé (cumul depuis la création de la clé).
-- Pas de colonne token : on ne montre que l'alias.
CREATE OR REPLACE VIEW monitoring.v_keys AS
SELECT
    key_alias                                                                       AS cle,
    spend                                                                           AS depense_usd,
    max_budget                                                                      AS plafond_usd,
    CASE WHEN max_budget IS NOT NULL THEN GREATEST(max_budget - spend, 0) END       AS restant_usd,
    CASE WHEN max_budget > 0 THEN ROUND((100 * spend / max_budget)::numeric, 1) END AS pct_utilise,
    COALESCE(blocked, false)                                                        AS bloquee
FROM "LiteLLM_VerificationToken"
WHERE key_alias IS NOT NULL;

GRANT USAGE ON SCHEMA monitoring TO grafana_ro;
GRANT SELECT ON monitoring.v_spend, monitoring.v_keys TO grafana_ro;
