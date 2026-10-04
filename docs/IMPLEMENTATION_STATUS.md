# État d'implémentation

_Dernière mise à jour : 2026-10-01 (version 1.0.0 envoyée à Apple, build 30 ; plan 1.1 « difficulté et progression » décidé)_

## Lire d'abord
`README.md` → ce fichier → `ARCHITECTURE.md` → `DECISIONS.md`. Détails au besoin : `ADAPTIVE.md`, `DATABASE.md`, `DESIGN_SYSTEM.md`, `QUESTIONS.md`, `KNOWN_ISSUES.md`.

## Ce qui fonctionne (testé)
| Domaine | État | Preuve |
|---|---|---|
| Schéma + RLS + droits | ✅ | `supabase/tests/40_security.sql` |
| Daily serveur (génération, service, verdict, temps, série, jokers, percentile, revue, expiration, minuit, fuseaux, double soumission) | ✅ | `10_daily.sql` |
| Adaptatif (compétences domaine/sous-domaine, calibration bornée, élargissement, questions problématiques, sélection par bandes, erreurs & maîtrise) | ✅ | `20_adaptive.sql` |
| Elo (provisoire 5 parties, fenêtres de cote, points, variation de cote, simulation de convergence) | ✅ | `70_rating.sql` |
| Bouclier (2e essai payé, demi-réussite) · « Corrige tes erreurs » (remboursement d'Elo plafonné au niveau d'avant) | ✅ | `98_second_chance.sql`, `99_correction.sql` |
| Pubs récompensées vérifiées par le serveur (SSV AdMob), limites par jour / mois, mode test admin | ✅ | `99_ads.sql`, fonction Edge `admob-ssv` |
| Algo : hasard (QCM, Vrai/Faux), thèmes équilibrés, révision espacée | ✅ | `80_algo.sql` |
| Objectifs jour/semaine (progression serveur, récompenses uniques), récap des semaines, historique du Daily | ✅ | `90_quests.sql` |
| Économie (ledger, plafonds, aides), pseudo, amis, parrainage anti-abus, ligues, suppression de compte | ✅ | `30_social_economy.sql` |
| Contenu (3 975 questions dont 105 expertes, 3 à 5 thèmes ≥ 20 questions par domaine, calibrage initial `docs/CALIBRATION.md`) | ✅ | `build-seed.mjs` en CI, `scripts/wikidata/` |
| Anti-répétition (familles) + équilibre Surprise | ✅ | migrations 0009-0010, tests SQL |
| Mode démo + captures + build Appetize | ✅ | workflow « Captures d'écran », `docs/screenshots` |
| `CultFiveCore` (modèles, contrat JSON sur fixtures réelles, évaluateur = SQL, pavé numérique, client Auth/RPC, refresh unique, file hors-ligne) | ✅ | `swift test` en CI |
| App iOS : toutes les fonctionnalités V1 codées (voir ci-dessous) | ✅ build + tests unitaires en CI (macOS 15) · 🟡 **pas encore essayée sur appareil** avec un vrai projet Supabase | job CI `ios` |

## App iOS — écrans
Onboarding (accueil → 3 vraies questions → niveau → intérêts → compte → pseudo) · Accueil « 5 du jour » · Session Daily · Résultat · Revue · Jouer (partie rapide, « Revoir mes erreurs », domaines ; par domaine : classée = tous les thèmes, ou entraînement libre avec thèmes, difficulté, nombre, chrono) · Lancement de partie (repères + 3-2-1) · Domaine (Elo, provisoire ou confirmé, thèmes, courbe, stats, erreurs) · Résumé de partie (dont « Corrige tes erreurs ») · Amis (demandes, liste avec le 5 du jour, recherche, **duels** par ami ou par lien) · Ligues (création, code, classement, période précédente) · Invitation/parrainage · Profil (portrait, carte Elo, chiffres, « Ce que tu sais », calendrier 35 j, trophées) · Réglages (page poussée : pseudo, apparence clair/sombre/iPhone, notifications, vibrations, âge, compte, aide et légal ; enregistrement immédiat) · Compte (Apple / e-mail OTP, liaison du compte anonyme) · Partage 9:16 (3 modèles ; Daily, profil avec radar, question du jour). Design « Pop » (voir `DESIGN_SYSTEM.md`) : 🟡 compilé en CI, rendu à valider à l'œil sur Appetize.

## Phases (plan du cahier des charges)
| Phase | État |
|---|---|
| 0 Analyse & architecture | ✅ |
| 1 Setup iOS + design system | ✅ |
| 2 Onboarding | ✅ codé |
| 3 Daily complet | ✅ serveur testé · UI codée |
| 4 Banque + backend | ✅ (admin web ❌, génération IA ❌) |
| 5 Adaptation | ✅ |
| 6 Jouer | ✅ |
| 7 Profil/stats/erreurs | ✅ |
| 8 XP/monnaie/trophées | ✅ |
| 9 Amis/parrainage/ligues | ✅ |
| 10 Partage | ✅ |
| 11 Notifications | ✅ locales · push social ❌ |
| 12 Polish/perf/tests | ⏳ après premiers retours sur appareil |
| 13 App Store readiness | ⏳ (pages légales, AASA, captures, fiche) |

## Serveur en ligne (2026-09-28)
- Projet Supabase **sibpncsjsdtjcjxbfryk** (Irlande, eu-west-1) : 18 migrations, 4 327 questions, 49 thèmes, maintenance planifiée (pg_cron, toutes les 15 min). Contrôles de sécurité passés (restent des avertissements attendus : tables sans politique = accès par fonctions uniquement ; fonctions appelables = API du jeu).
- L'app pointe sur ce serveur (`ios/Config/App.xcconfig`, clé anon publique). Mode démo : argument `-demo`.
- Installation faite en téléchargeant les fichiers du dépôt depuis la base (extension `http`, à une version précise) : `seed.sql` pèse 2,7 Mo.
- À régler dans le tableau de bord Supabase : connexions anonymes, modèle d'e-mail avec le code à 6 chiffres, connexion Apple (après le compte développeur).

## Prochaines étapes
**Sortie 1.0.0 (en cours, 2026-10-01)** : fiche App Store remplie (textes et marche à suivre dans `APP_STORE.md`, captures dans `docs/screenshots/app-store` et `app-store-6.5`), statut de commerçant DSA déclaré (adresse modifiable dans App Store Connect → Business). Build 29 refusé au contrôle automatique (ITMS-91064 : `NSPrivacyTracking` vrai sans domaines) ; corrigé dans le build 30 (le suivi d'AdMob est déclaré par le SDK Google). Après publication : relier l'app dans AdMob, vérifier les premiers push et l'onglet Santé de l'admin.

**Version 1.1 « difficulté et progression »** (décidée par le propriétaire, voir D-039 ; étapes détaillées à présenter avant de coder) :
1. Recalibrer toute la banque : les estimations sont trop optimistes (≈ 11 points d'écart mesurés sur 723 réponses classées : « facile » prévu 77 %, réel 66 % ; « moyen » 62 % → 51 %). Correction globale puis recalcul hebdomadaire avec les vraies réponses ; l'avis des joueurs prend le dessus plus vite sur l'estimation de départ (sinon l'Elo de tous baisse lentement).
2. Réévaluer les 6 306 questions avec une grille à exemples concrets (ex. capitales : facile Italie, Espagne, Japon ; moyen Portugal, Hongrie, Colombie, Croatie ; difficile Biélorussie, Kirghizistan). 87 capitales sont aujourd'hui « faciles » dont Minsk, Bogota, Zagreb.
3. Ajouter de la « culture de base » : classiques accessibles à tous, ni bêtes ni pièges, en quantité modérée (le tiers accessible de chaque partie).
4. Plus de variété en géographie (284 questions de capitales sur 1 562).
5. Mélange dans chaque partie classée autour du niveau du joueur (≈ 3 accessibles, 5 à son niveau, 2 qui piquent sur 10), adaptation douce conservée ; viser ≈ 70 % de réussite réelle (aujourd'hui ≈ 55 %).
6. Départ de l'Elo à **500** (placement rapide vers le vrai niveau), rangs et trophées de maîtrise redécoupés (seuils à valider), joueurs existants décalés sans perte de place relative.
7. Retirer la pastille Facile / Moyen / Difficile des questions.
8. Petits correctifs : boutons d'aide en grille de 2 colonnes (les libellés se coupent sur plusieurs lignes) ; tickets des coffres redessinés (le « 50/50 » est coupé dans le ticket bleu).

## Commandes utiles
`scripts/test-db.sh` · `scripts/gen-fixtures.sh` (après test-db) · `node scripts/build-seed.mjs` · `python3 scripts/make-icon.py <sortie>` · `node scripts/icons/render.mjs` (icônes 3D : coffres, graines, flamme, joker, tickets, arrosoir → `Assets.xcassets/Icons`) · `cd ios && xcodegen`
