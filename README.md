# Brainlix

App iOS native de culture générale. Le **5 du jour** (5 questions, une tentative officielle) comme rituel, un mode **Jouer** adaptatif, des **amis** et des **ligues privées**, un vrai profil de connaissances.

> Nouvelle session ? Lire dans l'ordre : `docs/IMPLEMENTATION_STATUS.md` → `docs/ARCHITECTURE.md` → `docs/DECISIONS.md`. Puis uniquement les fichiers utiles à la tâche.

## Arborescence
```
docs/          mémoire du projet (produit, archi, design, base, décisions, statut)
content/       banque curée (taxonomy.json, questions/*.json)
scripts/       build-seed.mjs, test-db.sh, gen-fixtures.sh, make-icon.py
supabase/      migrations SQL, seed.sql (généré), tests SQL
ios/           project.yml (XcodeGen), CultFive/ (app), Packages/CultFiveCore/ (logique pure + client)
```

## Démarrer

### Backend (Supabase)
1. Créer un projet Supabase. Dans **Auth → Providers** : activer *Anonymous sign-ins*, *Email* (OTP à 6 chiffres) et *Apple* (Services ID + clé).
2. `supabase link --project-ref <ref>` puis `supabase db push` (applique `supabase/migrations`).
3. Charger le contenu : `psql "$DATABASE_URL" -f supabase/seed.sql`.
4. Vérifier que pg_cron est activé (Database → Extensions) : la migration 0008 planifie `cron_daily_maintenance()`.
5. Se déclarer admin : `insert into app_admins (user_id) values ('<uuid>');`

### App iOS
```bash
brew install xcodegen
cp ios/Config/Secrets.xcconfig.example ios/Config/Secrets.xcconfig   # URL + clé anon + Team ID
cd ios && xcodegen && open CultFive.xcodeproj
```
Capacités requises sur l'App ID `app.brainlix.ios` (équipe `BM85BF2WVQ`) : *Sign in with Apple*, *Associated Domains* (`applinks:brainlix.site`), *Push Notifications*.

### TestFlight
Onglet Actions → **TestFlight** → *Run workflow* (`.github/workflows/testflight.yml`) : build Release (serveur de production, sans mode démo), signature automatique, envoi sur App Store Connect. Numéro de build = numéro d'exécution du workflow.
Secrets du dépôt : `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (clé App Store Connect API, accès *Admin* pour la signature gérée par Apple).

### Site (brainlix.site)
Dossier `site/` : HTML statique sans build, déployé par Vercel (répertoire racine `site`, framework « Other »). `vercel.json` gère les URL propres, les liens `/i/ /l/ /d/` et l'en-tête JSON de `apple-app-site-association`.

### Tests
```bash
PGHOST=… PGUSER=postgres scripts/test-db.sh              # migrations + seed + tests SQL (Postgres 16)
swift test --package-path ios/Packages/CultFiveCore       # logique + contrat JSON (macOS)
cd ios && xcodegen && xcodebuild test -scheme CultFive -destination 'platform=iOS Simulator,name=iPhone 16'
```
La CI (`.github/workflows/ci.yml`) exécute les trois.

### Contenu
Éditer `content/questions/*.json`, puis `node scripts/build-seed.mjs` (valide et régénère `supabase/seed.sql`). Format dans `docs/QUESTIONS.md`.
