# Banque de questions

## Source
- `content/taxonomy.json` : domaines (avec `daily_slot`) et sous-domaines.
- `content/questions/*.json` : questions curées. Un fichier par pilier (`calc`, `french`, `geography`, `history`) + `surprise.json` (autres domaines).
- `node scripts/build-seed.mjs` valide tout (échec au moindre défaut) et génère `supabase/seed.sql`. `--check` : validation seule. La CI vérifie que le seed est à jour.

État session 2 : **273 questions** (calcul 48 · français 46 · géographie 53 · histoire 47 · sciences 18 · logique 9 · arts 11 · sport 9 · cinéma 8 · musique 8 · techno 7 · nature 9). Fichiers `*_2.json` = vague 2, riche en types non-QCM (classements, associations, vrai/faux, calcul).

## Format (auteur)
```json
{"key":"geo-001", "concept":"geography.capitals.australia", "label":"Capitale de l'Australie",
 "type":"mcq", "difficulty":40, "prompt":"Quelle est la capitale de l'Australie ?",
 "options":["Canberra*","Sydney","Melbourne","Perth"],
 "explanation":"…", "takeaway":"…", "hint":"…", "context":"…", "source":"…", "fact_as_of":"2023-04-24"}
```
| type | champs | réponse |
|---|---|---|
| `mcq` | `options` (2–4), bonne marquée `*` ; `keep_order` facultatif | option |
| `true_false` | `answer: true/false` | booléen |
| `numeric` | `answer`, `tolerance` (déf. 0), `unit` | nombre |
| `ordering` | `items` **dans le bon ordre** (3–5) — mélangés au service | ordre |
| `pairs` | `pairs: [[gauche, droite], …]` (3–5) | associations |
| `map_pick` | `region {lat, lon, span}`, `pins` (2–5) dont un `correct: true` | point |

Règles éditoriales :
- **Un concept = une connaissance.** Deux formulations du même fait partagent `concept` (même `label`).
- Explication ≤ 600 caractères, idéalement 1–2 phrases. « À retenir » : une phrase mémorisable, facultative.
- Faits évolutifs (population, records, mesures) : `source` + `fact_as_of`.
- Difficulté initiale 5–95 ; plage effective ±10 par défaut (la calibration ne sort de la plage qu'avec des preuves solides, voir ADAPTIVE.md).
- Éviter les ambiguïtés, les « pièges » de formulation et les faits contestés (ex. Nil vs Amazone : exclu).
- Les ids d'options sont des hash opaques générés : l'ordre d'écriture ne révèle rien.

## Génération IA (pipeline prévu)
`generation_batches` + `admin_import(questions, 'ai', batch)` : les questions IA arrivent en `review`, **jamais** publiées directement (forcé en SQL, `_upsert_question`). Validation humaine via `admin_question_set_status(id, 'published')`, tracée dans `question_reviews`.

## Priorités de contenu
1. Plus de types non-QCM en Français et Histoire (variété du Daily).
2. ≥ 60 questions par pilier avant le lancement (le Daily évite la réutilisation à 180 j ; avec ~25/pilier, la variété est garantie ~1 mois puis se relâche proprement).
3. Doublons de concepts (mêmes connaissances, formulations différentes) pour « Mes erreurs ».
