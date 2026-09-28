# Architecture

## Vue d'ensemble

```
┌──────────────────────────── iOS (SwiftUI, iOS 17+) ────────────────────────────┐
│  App/            point d'entrée, AppModel (session, auth, routing)               │
│  DesignSystem/   tokens (couleurs, typo, espacements), composants, haptics      │
│  Features/       Onboarding · Daily · Play · Friends · Profile · Stats · Share  │
│  Services/       SupabaseService + repositories (Daily, Play, Social, Profile)  │
│  Packages/CultFiveCore (SPM, pur Swift, sans UIKit)                              │
│      modèles, évaluation des réponses, parsing numérique, XP/niveaux,           │
│      machine d'état d'une session de questions, file hors-ligne                  │
└───────────────┬──────────────────────────────────────────────────────────────────┘
                │ supabase-swift (Auth + PostgREST RPC)
┌───────────────▼──────────────── Supabase ───────────────────────────────────────┐
│  Auth : anonyme → Sign in with Apple / e-mail OTP (liaison d'identité)          │
│  Postgres : schéma `public` (tables) + fonctions RPC SECURITY DEFINER            │
│      = logique métier autoritaire : Daily, score, percentile, compétences,      │
│        erreurs, ledger XP/graines, série, parrainage, amis, ligues              │
│  RLS : activée partout ; lecture directe limitée à ses propres lignes ;         │
│        `questions` jamais lisible directement (réponses secrètes)               │
│  pg_cron : génération du Daily J+2, expiration des runs                          │
│  Edge Functions : génération IA de lots (clé secrète), push (plus tard)         │
└──────────────────────────────────────────────────────────────────────────────────┘
┌───────────── Contenu ─────────────┐
│ content/questions/*.json (curé)   │ → scripts/build-seed.mjs → supabase/seed.sql
│ Admin web (phase ultérieure)      │ → écrit en base via RPC admin_*
└───────────────────────────────────┘
```

## Principes
1. **Le serveur est autoritaire** pour tout ce qui compte : Daily, score, temps officiel, percentile, XP, graines, série, parrainage, ligues. Le client n'envoie que des *réponses* et des *mesures*, jamais des *résultats*.
2. **La logique métier vit dans Postgres (RPC plpgsql)**, pas dans des Edge Functions : transactionnel, pas de cold start, testable en SQL pur (`supabase/tests`). Les Edge Functions ne servent que quand un secret externe est nécessaire (IA, APNs).
3. **Une seule banque de questions** alimente Daily, Jouer, Erreurs, Défi.
4. **Les réponses du Daily ne quittent jamais le serveur avant la validation** de la question par l'utilisateur. En mode Jouer, les packs contiennent les réponses (jeu hors-ligne possible) ; l'enjeu (XP/graines plafonnés) est faible, et les questions des Daily présents/futurs sont exclues des packs.
5. **Idempotence** : chaque réponse porte un `client_attempt_id` (UUID) ; toute RPC d'écriture peut être rejouée sans double effet.
6. **Ledger** : XP et graines ne sont jamais modifiés directement ; on insère une transaction (clé d'idempotence unique), un trigger tient le solde à jour.

## Client iOS
- SwiftUI + Observation (`@Observable`), iOS 17 minimum (NavigationStack, `ImageRenderer`, `sensoryFeedback`, `ContentUnavailableView`).
- Projet généré par **XcodeGen** (`ios/project.yml`) : pas de `.pbxproj` versionné à la main → diffs lisibles, pas de conflits.
- Une seule dépendance externe : `supabase-swift`.
- Injection de dépendances : `AppEnvironment` (struct de repositories protocolés) passé via `@Environment`. Les implémentations de prévisualisation (`Preview*`) ne sont compilées que pour les SwiftUI Previews ; aucune fonctionnalité livrée ne repose sur des données factices.
- Cache : `URLCache` + cache disque JSON des packs de questions et du profil (`Services/Cache`). File d'attente hors-ligne des tentatives Jouer (`OfflineAttemptQueue` dans Core), vidée au retour réseau.
- Marque centralisée : `CultFive/App/Brand.swift` (nom, signatures, nom de la monnaie, mascotte, URL d'invitation). Rien d'autre ne contient « Brainlix » en dur.
- Secrets : `ios/Config/Secrets.xcconfig` (ignoré par git) → `Info.plist` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). La clé anon est publique par nature ; aucune clé service n'est jamais embarquée.

## Structure des dossiers
```
README.md
docs/                    mémoire persistante du projet (lire STATUS en premier)
content/questions/       banque curée (JSON, 1 fichier par domaine)
scripts/                 build-seed.mjs (JSON → seed.sql), outils
supabase/
  config.toml
  migrations/            schéma + fonctions (ordre numérique)
  seed.sql               généré — ne pas éditer
  tests/                 tests SQL (bootstrap local + assertions)
  functions/             Edge Functions (Deno)
ios/
  project.yml            XcodeGen
  Config/                xcconfig (Secrets.xcconfig.example)
  CultFive/
    App/                 CultFiveApp, AppModel, Brand, RootView, TabBar
    DesignSystem/        Tokens, Typography, Components/, Haptics, Mascot/
    Features/            Onboarding/ Daily/ Play/ Friends/ Profile/ Share/ Questions/
    Services/            SupabaseService, *Repository
    Resources/           Assets.xcassets, Localizable.xcstrings
  CultFiveTests/
  Packages/CultFiveCore/ Package.swift, Sources/, Tests/
.github/workflows/       ci.yml (SQL sur Postgres + build/test iOS sur macOS)
```

## Temps et fuseaux (Daily)
- La **date du Daily d'un utilisateur** = date courante *côté serveur* (`now()`) dans le fuseau `profiles.timezone`. L'heure de l'appareil n'est jamais utilisée.
- Changement de fuseau : accepté au plus une fois toutes les 20 h (voyages OK, bascule répétée pour « voir demain » impossible). Une seule tentative par `(user, daily_date)` (contrainte unique) : pas de rejeu possible.
- Un run démarré à 23:59 reste rattaché à sa date ; délai de grâce de 30 min pour finir. Passé ce délai, les questions non répondues comptent fausses et le run est clôturé (`status = expired`, score officiel = réponses données).
- Temps officiel d'une question = `least(temps client, temps serveur servi→répondu)`, borné à [0,3 s ; 120 s]. Le temps de lecture des explications n'est jamais compté (l'horloge démarre à `daily_question`, s'arrête à `daily_answer`).

## Sécurité
Voir DATABASE.md § Sécurité. Résumé : RLS partout, `revoke` des tables sensibles, RPC `security definer` avec `search_path` figé, validation des entrées, plafonds journaliers sur les gains hors Daily, parrainage qualifié seulement après le premier Daily terminé d'un compte non anonyme.

## Algorithme adaptatif
Voir `docs/ADAPTIVE.md`.
