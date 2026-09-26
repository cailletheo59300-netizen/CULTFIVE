# État d'implémentation

_Dernière mise à jour : session 2 — 2026-09-26 (design Pop, 0.5.0)_

## Lire d'abord
`README.md` → ce fichier → `ARCHITECTURE.md` → `DECISIONS.md`. Détails au besoin : `ADAPTIVE.md`, `DATABASE.md`, `DESIGN_SYSTEM.md`, `QUESTIONS.md`, `KNOWN_ISSUES.md`.

## Ce qui fonctionne (testé)
| Domaine | État | Preuve |
|---|---|---|
| Schéma + RLS + droits | ✅ | `supabase/tests/40_security.sql` |
| Daily serveur (génération, service, verdict, temps, série, jokers, percentile, revue, expiration, minuit, fuseaux, double soumission) | ✅ | `10_daily.sql` |
| Adaptatif (compétences domaine/sous-domaine, calibration bornée, élargissement, questions problématiques, sélection par bandes, erreurs & maîtrise) | ✅ | `20_adaptive.sql` |
| Économie (ledger, plafonds, aides), pseudo, amis, parrainage anti-abus, ligues, suppression de compte | ✅ | `30_social_economy.sql` |
| Contenu (3 143 questions : 449 curées + 2 694 générées Wikidata/Natural Earth) | ✅ | `build-seed.mjs` en CI, `scripts/wikidata/` |
| Anti-répétition (familles) + équilibre Surprise | ✅ | migrations 0009-0010, tests SQL |
| Mode démo + captures + build Appetize | ✅ | workflow « Captures d'écran », `docs/screenshots` |
| `CultFiveCore` (modèles, contrat JSON sur fixtures réelles, évaluateur = SQL, pavé numérique, client Auth/RPC, refresh unique, file hors-ligne) | ✅ | `swift test` en CI |
| App iOS : toutes les fonctionnalités V1 codées (voir ci-dessous) | ✅ build + tests unitaires en CI (macOS 15) · 🟡 **pas encore essayée sur appareil** avec un vrai projet Supabase | job CI `ios` |

## App iOS — écrans
Onboarding (accueil → 3 vraies questions → niveau → intérêts → compte → pseudo) · Accueil « 5 du jour » · Session Daily · Résultat · Revue · Jouer (rapide, surprise, défi, erreurs, par domaine/sous-domaine) · Domaine (niveau, sous-domaines, courbe, stats, erreurs) · Résumé de partie · Amis (demandes, liste avec le 5 du jour, recherche) · Ligues (création, code, classement, période précédente) · Invitation/parrainage · Profil (portrait, chiffres, « Ce que tu sais », calendrier 35 j, trophées) · Réglages (pseudo, notifications, âge, compte, suppression) · Compte (Apple / e-mail OTP, liaison du compte anonyme) · Partage 9:16 (3 modèles ; Daily, profil avec radar, question du jour). Design « Pop » (voir `DESIGN_SYSTEM.md`) : 🟡 compilé en CI, rendu à valider à l'œil sur Appetize.

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

## Prochaines étapes
1. **Propriétaire** : créer le projet Supabase (Auth anonyme + Apple + e-mail), `db push`, seed, renseigner `Secrets.xcconfig`, lancer sur iPhone → retours.
2. Contenu : viser ≥ 150 par pilier et étoffer les domaines surprise (outil IA + validation).
3. Admin web (RPC prêtes) + Edge Function de génération IA (lots en `review`).
4. Polish après retours (animations, micro-copies, accessibilité VoiceOver sur appareil).
5. App Store : pages légales, AASA, métadonnées, captures.

## Commandes utiles
`scripts/test-db.sh` · `scripts/gen-fixtures.sh` (après test-db) · `node scripts/build-seed.mjs` · `python3 scripts/make-icon.py <sortie>` · `cd ios && xcodegen`
