# Problèmes connus / limites

| # | Sujet | Détail | Piste |
|---|---|---|---|
| K-1 | Banque encore petite | 153 questions ; ~25 par pilier. Variété parfaite du Daily ≈ 1 semaine pour les types, ~1 mois pour la non-réutilisation (les replis restent sans doublon à 14 j). | Écrire ≥ 60/pilier, plus de types non-QCM (FR, Histoire). |
| K-2 | Pas d'admin web | Les RPC `admin_*` existent ; pas encore d'interface. Supabase Studio + SQL en attendant. | Phase dédiée (Next.js privé ou page artefact). |
| K-3 | Génération IA non branchée | Schéma et garde-fous prêts (`generation_batches`, statut `review` forcé). Pas d'Edge Function d'appel au modèle. | Edge Function `generate-questions` (clé API côté serveur). |
| K-4 | Liens universels | `applinks:cultfive.app` déclaré ; le fichier `apple-app-site-association` du domaine reste à publier. Le schéma `cultfive://` fonctionne. | Héberger AASA. |
| K-5 | Push social absent | Notifications locales uniquement (D-015). | APNs via Edge Function. |
| K-6 | Estimation du percentile | Suppose une population N(50, 15²). Ne tient pas compte du temps. Étiquetée « estimation ». | Recalibrer la référence sur les données réelles. |
| K-7 | Hors-ligne Daily | Le Daily exige le réseau à chaque réponse (choix : score officiel protégé). Coupure → réponse gardée, bouton « Renvoyer ». | — (voulu) |
| K-8 | Localisation | Textes en français dans le code ; catalogue de chaînes à extraire (`SWIFT_EMIT_LOC_STRINGS` activé). | Avant l'anglais. |
| K-9 | Carte `map_pick` | Imagerie satellite (sans libellés, pour ne pas donner la réponse) : lourde en données. | Tuiles simplifiées si besoin. |
| K-10 | Pages légales | `cultfive.app/confidentialite` et `/conditions` référencées mais à publier (exigence App Store). | Avant soumission. |
