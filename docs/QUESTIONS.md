# Banque de questions

## Source
- `content/taxonomy.json` : domaines (avec `daily_slot`) et sous-domaines.
- `content/questions/*.json` : questions curées. Un fichier par pilier (`calc`, `french`, `geography`, `history`) + `surprise.json` (autres domaines).
- `node scripts/build-seed.mjs` valide tout (échec au moindre défaut) et génère `supabase/seed.sql`. `--check` : validation seule. La CI vérifie que le seed est à jour.

État session 2 : **273 questions** (calcul 48 · français 46 · géographie 53 · histoire 47 · sciences 18 · logique 9 · arts 11 · sport 9 · cinéma 8 · musique 8 · techno 7 · nature 9). Fichiers `*_2.json` = vague 2, riche en types non-QCM (classements, associations, vrai/faux, calcul).

## Questions générées depuis Wikidata (CC0)
- `scripts/wikidata/fetch.mjs` : requêtes SPARQL → cache versionné `scripts/wikidata/cache/*.json` (reproductible sans réseau ; `node scripts/wikidata/fetch.mjs` pour rafraîchir).
- `scripts/wikidata/generate.mjs` : modèles de questions → `content/questions/wd_*.json` (déterministe). `scripts/wikidata/french.mjs` : articles et prépositions des noms de pays (règles + exceptions relues).
- `scripts/wikidata/rejects.json` : clés écartées à la relecture.
- Modèles : capitale (et inverse), drapeau, continent, grande ville → pays, classements population/superficie, siècle de naissance, classements de naissances, année de bataille (≤ 1945), symbole chimique (et inverse), auteur de livre, peintre de tableau, réalisateur de film, **localisation sur carte** (capitale parmi 4 points), **monnaie**, **langue officielle**, **site UNESCO → pays**, **silhouette du pays** (contours Natural Earth, domaine public, dans `payload.shape` d'un QCM). Depuis 0.5.1 : **famille d'instrument** (cordes / vent / percussion ; instruments à clavier et classements discutables écartés), **groupe → pays** et **décennie de formation**, **Coupe du monde** (vainqueur, pays hôte, éditions ≤ 2022), **ville des JO** (table relue, contrôlée contre Wikidata qui mélange villes et stades), **inventeur ↔ invention** (liste relue : attributions discutables, inventions multiples et inventions éponymes écartées).
- **Familles** (`family`) : chaque modèle a une famille (capital, flag, map, shape…). Le serveur n'enchaîne jamais deux questions de la même famille en Jouer (≤ 2 par partie) et n'en met qu'une par Daily (migration 0010). Plusieurs formulations par modèle (`vary`).
- Garde-fous : un seul chef-lieu, capitales contestées exclues (Israël, Guinée équatoriale, Nauru), continents ambigus exclus, titres homonymes exclus, œuvres à plusieurs auteurs exclues, écarts nets dans les classements, dédoublonnage avec la banque curée.
- Niveau initial : notoriété (liens Wikipédia, population, continent) ; plage ±10, recalibrée par les réponses des joueurs.
- `origin = 'import'`, source « Wikidata ».

Écrites à la main plutôt que générées : **nature** (Wikidata donne des noms latins et classe les oiseaux parmi les reptiles au sens cladistique — piège pour un quiz), **logique**, informatique, règles du sport, musique classique (`content/questions/small_domains.json`, 96 questions).

État : **3 143 questions** (2 694 générées + 449 curées). Par domaine : géographie 1 544 · histoire 499 · arts 301 · musique 207 · sport 110 · sciences 92 · calcul 88 · français 86 · tech 81 · cinéma 59 · nature 46 · logique 30.

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
