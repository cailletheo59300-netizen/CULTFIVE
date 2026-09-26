# Problèmes connus / limites

| # | Sujet | Détail | Piste |
|---|---|---|---|
| K-1 | Banque déséquilibrée | 1 886 questions, mais Calcul (48) et Français (46) restent minces face à Géographie (784) et Histoire (504) ; le créneau « Surprise » du Daily est dominé par Arts (311). | Rééquilibrer le tirage « Surprise » par domaine ; écrire du Calcul/Français (peu adaptés à Wikidata). |
| K-11 | Questions générées : style répétitif | Les modèles Wikidata produisent des énoncés similaires (« Quelle est la capitale… »). Explications courtes. | Enrichir les explications (faits complémentaires), varier les formulations. |
| K-2 | Pas d'admin web | Les RPC `admin_*` existent ; pas encore d'interface. Supabase Studio + SQL en attendant. | Phase dédiée (Next.js privé ou page artefact). |
| K-3 | Génération IA non branchée | Schéma et garde-fous prêts (`generation_batches`, statut `review` forcé). Pas d'Edge Function d'appel au modèle. | Edge Function `generate-questions` (clé API côté serveur). |
| K-4 | Liens universels | `applinks:cultfive.app` déclaré ; le fichier `apple-app-site-association` du domaine reste à publier. Le schéma `cultfive://` fonctionne. | Héberger AASA. |
| K-5 | Push social absent | Notifications locales uniquement (D-015). | APNs via Edge Function. |
| K-6 | Estimation du percentile | Suppose une population N(50, 15²). Ne tient pas compte du temps. Étiquetée « estimation ». | Recalibrer la référence sur les données réelles. |
| K-7 | Hors-ligne Daily | Le Daily exige le réseau à chaque réponse (choix : score officiel protégé). Coupure → réponse gardée, bouton « Renvoyer ». | — (voulu) |
| K-8 | Localisation | Textes en français dans le code ; catalogue de chaînes à extraire (`SWIFT_EMIT_LOC_STRINGS` activé). | Avant l'anglais. |
| K-9 | Carte `map_pick` | Imagerie satellite (sans libellés, pour ne pas donner la réponse) : lourde en données. | Tuiles simplifiées si besoin. |
| K-10 | Pages légales | `cultfive.app/confidentialite` et `/conditions` référencées mais à publier (exigence App Store). | Avant soumission. |
