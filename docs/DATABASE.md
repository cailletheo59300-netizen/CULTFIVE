# Base de données (Supabase / PostgreSQL)

Migrations : `supabase/migrations/2026092600000{1..8}_*.sql`. Tests : `supabase/tests/*.sql` (`scripts/test-db.sh`).

## Tables
| Table | Rôle | Accès client direct |
|---|---|---|
| `domains`, `subdomains` | Référentiel (12 domaines, sous-domaines). `domains.daily_slot` : pilier du Daily ou null = Surprise | lecture |
| `concepts` | Une connaissance unique (`geography.capitals.australia`). Plusieurs questions peuvent la mesurer | lecture |
| `questions` | Banque centrale. `payload` public / `answer` secret. Calibration : `difficulty_initial/min/max/observed/var`, `difficulty_effective` (générée = clamp), `confidence`, `answer_count`, `needs_review` | **aucun** (RPC) |
| `profiles` | Pseudo, fuseau, prior de challenge, intérêts, soldes (cache du ledger), série, compteurs, code de parrainage, préférences de notification | lecture de sa ligne |
| `user_skills` | Compétence par domaine **et** sous-domaine (`scope_id`), μ/σ², n | lecture |
| `user_skill_snapshots` | 1 point/jour/scope pour les courbes d'évolution | lecture |
| `user_concepts` | Historique par concept + **état d'erreur** (`failed`, `to_review`, `correct_once`, `mastered`) | lecture |
| `question_attempts` | Historique complet (contexte, réponse, temps, difficulté et niveau au moment, attendu, nb de vues). Idempotence `client_attempt_id` | lecture |
| `ledger` | XP et graines (une seule monnaie). Clé d'idempotence unique par utilisateur | lecture |
| `achievements`, `user_achievements` | 10 trophées | lecture |
| `daily_sets`, `daily_set_items` | Série du jour (commune à tous) | aucun |
| `daily_runs` | Tentative officielle (unique par utilisateur et date), score, temps, récompenses | lecture |
| `daily_answers` | Réponses du Daily : `served_at` / `answered_at` (horloge serveur), `counted_ms` | aucun |
| `play_sessions` | Packs servis (seules leurs questions sont acceptées à la soumission ; limite 60/h) | aucun |
| `friendships` | pending/accepted/declined/blocked, paire unique (`user_low`, `user_high`) | lecture (parties) |
| `referrals`, `user_devices` | Parrainage + empreintes d'appareil hachées (anti-abus) | lecture (parties) / aucun |
| `leagues`, `league_members` | Ligues privées (≤ 50 membres, ≤ 10 ligues/joueur). Classement **calculé** depuis `daily_runs` (pas de table de scores) | lecture (membres) |
| `app_admins`, `blocked_terms`, `generation_batches`, `question_reviews` | Administration, modération des pseudos, traçabilité IA/validation | aucun |

## RPC exposées (rôle `authenticated`)
- **Daily** : `daily_status`, `daily_start`, `daily_question(run, position)`, `daily_answer(run, position, given, client_ms)`, `daily_result(date?)`, `daily_review(date?)`, `daily_history(days)`
- **Jouer** : `onboarding_pack`, `play_pack(mode, domain?, subdomain?, count)`, `play_submit(session, attempts)`, `play_spend_help(session, question, kind)`
- **Profil** : `profile_me`, `handle_available`, `set_handle`, `profile_update(p)`, `complete_onboarding(level, interests)`, `set_timezone`, `register_device`, `skills_overview`, `domain_stats(domain)`, `errors_overview`, `achievements_mine`, `delete_account`
- **Social** : `search_handles`, `friend_request`, `friend_respond`, `friend_remove`, `friend_block`, `friends_overview`, `referral_claim(code, device_hash)`, `referral_overview`, `league_create`, `league_join`, `league_leave`, `league_rename`, `league_standings(id, offset)`, `leagues_mine`
- **Admin** (table `app_admins`) : `admin_dashboard`, `admin_questions(filter, limit, offset)`, `admin_question_upsert`, `admin_import(questions, origin, batch)`, `admin_question_set_status`, `admin_daily_get/generate/replace`, `admin_batch_create`
- **Planifiée** : `cron_daily_maintenance()` toutes les 15 min via pg_cron (expire les runs abandonnés, génère J-1…J+2)

Les erreurs métier sont levées avec un code lisible dans `message` (`daily_closed`, `handle_taken`, `insufficient_seeds`…) ; le client les traduit (`BackendError.humanMessage`).

## Sécurité
- RLS activée sur toutes les tables ; aucune policy d'écriture : **toute écriture passe par une RPC `security definer`** (`search_path` figé).
- `revoke execute` sur toutes les fonctions puis `grant` explicite des seules RPC publiques. Les fonctions `_internes` sont inexécutables depuis l'API (testé).
- `questions` illisible : les réponses du Daily ne sortent qu'après validation ; les packs Jouer excluent les questions des Daily d'hier à J+2.
- Horloge : `_now()` ; surcharge de test ignorée dès que `session_user = authenticator` (requêtes API) — testé.
- Anti-triche Daily : une tentative par (user, date) ; date calculée côté serveur ; fuseau modifiable 1×/20 h ; temps compté = min(temps serveur, max(temps client, temps serveur − 2 s)) borné [0,3 s ; 120 s] ; réponse jamais servie avant `daily_question`, questions dans l'ordre.
- Gains hors Daily plafonnés/jour : XP de jeu 300, graines de jeu 20, corrections 10/jour (et seulement si l'erreur a ≥ 1 h).
- Parrainage : compte non anonyme < 7 jours, pas soi-même, appareil différent de l'invitant, appareil jamais utilisé pour un parrainage ; parrain payé au 1er Daily terminé du filleul, 20 max / 30 jours.

## Données de test locales
`scripts/test-db.sh` émule le minimum de Supabase (`supabase/tests/00_local_bootstrap.sql` : rôles, `auth.users`, `auth.uid()`), rejoue migrations + seed, puis les tests. Helpers `tst.*` (horloge, connexion simulée, assertions) dans `01_helpers.sql`.
