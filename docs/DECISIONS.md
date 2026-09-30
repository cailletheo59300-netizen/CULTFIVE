# Décisions

Format : décision · pourquoi · alternatives · conséquence. Ne pas rouvrir sans élément nouveau.

### D-001 · 2026-09-26 · SwiftUI natif, iOS 17 minimum
Pourquoi : Observation (`@Observable`), `Map` SwiftUI, `sensoryFeedback`, `ImageRenderer` matures. Alternatives : iOS 16 (plus de code de compatibilité), React Native/Flutter (moins natif, contraire au cahier des charges). Conséquence : ~95 % du parc iPhone actif couvert.

### D-002 · Projet généré par XcodeGen
Pourquoi : pas de `.pbxproj` versionné → pas de conflits, diffs lisibles, sessions Claude plus économes. Alternative : projet Xcode classique. Conséquence : `brew install xcodegen && cd ios && xcodegen` avant d'ouvrir.

### D-003 · Logique métier dans Postgres (RPC plpgsql `security definer`), pas dans des Edge Functions
Pourquoi : transactions atomiques (score + ledger + série + trophées), pas de cold start, testable en SQL pur, RLS naturelle. Alternatives : Edge Functions Deno (latence, pas de transaction multi-étapes simple), serveur dédié (coût). Conséquence : Edge Functions réservées aux secrets externes (IA, APNs).

### D-004 · Daily commun à tous (même série par date), non adaptatif individuellement
Pourquoi : condition d'un percentile et de ligues honnêtes. L'adaptatif s'exprime dans Jouer/Erreurs/Défi. Difficulté cible équilibrée [35, 45, 50, 55, 65]. Alternative : Daily personnalisé (percentile incomparable). Conséquence : « Daily+ » Premium futur = autre série, autre classement.

### D-005 · Date du Daily = date serveur dans le fuseau du profil ; fuseau modifiable 1×/20 h ; grâce de 30 min après minuit
Pourquoi : l'heure de l'appareil est manipulable ; les voyageurs doivent rester servis. Conséquence : un run commencé à 23:59 se termine sur sa date ; au-delà de la grâce, il expire (score = réponses données, pas de série).

### D-006 · Adaptation : Rasch + mise à jour bayésienne approchée (Glicko-1), σ₀ = 10, ±4/réponse
Voir ADAPTIVE.md. Alternatives : Elo (pas de confiance), IRT 2PL/3PL par lots (prématuré). Réglé en session 1 après observation des fixtures (±6 jugé brutal).

### D-007 · Percentile réel à partir de 100 participants, sinon « estimation » étiquetée
Estimation = Poisson-binomiale sur une population N(50, 15²) et les difficultés calibrées. Jamais présentée comme réelle.

### D-008 · Aucune aide payante dans le Daily
Pourquoi : pas de pay-to-win sur un classement. Les aides (50/50 15, indice 10, contexte 5 graines) n'existent qu'en Jouer.

### D-009 · Monnaie : les « graines »
Cohérente avec « Cultive ce que tu sais ». Une seule monnaie, ledger avec clé d'idempotence, solde en cache tenu par trigger.

### D-010 · Mascotte : Léon, un caméléon
Il prend la couleur du domaine : métaphore directe de l'adaptation, jamais scolaire (pas de chapeau, livre, ampoule). Dessiné en code (`Canvas`), sans asset. **Révisé par D-021** : redessiné en version Pop et doté d'un rôle (réactions aux réponses, série).

### D-011 · Client Supabase maison (≈ 300 lignes) au lieu de `supabase-swift`
Pourquoi : on n'utilise que Auth (anonyme, Apple id_token avec liaison, OTP e-mail, refresh) et les RPC ; zéro dépendance, surface stable, testable par transport simulé et fixtures. Alternative : SDK officiel (API qui bouge, dépendance lourde). Conséquence : si Realtime/Storage deviennent nécessaires, réévaluer le SDK.

### D-012 · Découverte avant inscription via compte anonyme Supabase
Liaison Apple (`link_identity`) ou e-mail (changement d'e-mail + OTP) sur le même user id : aucune perte de progression. **Pré-requis projet** : activer « Anonymous sign-ins » et Apple dans Supabase Auth.

### D-013 · Réponses du Jouer embarquées dans le pack
Pourquoi : verdict instantané, jeu hors-ligne. Risque de triche faible (XP/graines plafonnés, verdict recalculé serveur). Les questions des Daily J-1…J+2 sont exclues des packs.

### D-014 · Parrainage qualifié au premier Daily terminé du filleul
Pourquoi : déclencheur le plus coûteux à simuler en masse (compte non anonyme + appareil distinct + vraie partie). Invité payé à l'inscription (graines non transférables : aucun intérêt à multiplier les comptes).

### D-015 · Notifications locales uniquement en V1
Pourquoi : suffisant pour « Daily disponible » et « rappel du soir », zéro infrastructure, zéro spam (annulées si le Daily est fait). Push social (APNs via Edge Function) plus tard.

### D-016 · Identifiants d'options opaques (hash) générés par `build-seed.mjs`
Pourquoi : un id `a/b/c` ou l'ordre d'écriture révéleraient la bonne réponse. Mélange déterministe côté serveur (graine = run/session).

### D-017 · Contenu curé versionné en JSON (`content/questions`) → `seed.sql`
Pourquoi : relecture en PR, import idempotent (`external_key`). L'admin web écrira directement en base via les RPC `admin_*`. Les questions IA passent obligatoirement par `review` (impossible de publier directement, contraint en SQL).

### D-018 · Ordre des phases ajusté : backend (phase 4) avant Daily UI (phase 3)
Pourquoi : « pas de mocks » — un Daily sans serveur aurait été factice. Tout a été posé en une première passe, testé côté SQL, compilé côté iOS par la CI.

### D-019 · 2026-09-26 · Banques externes : Wikidata uniquement (pas OpenQuizzDB ni Open Trivia DB)
Pourquoi : Wikidata est CC0 (aucune obligation de citation ni de partage à l'identique), factuel et structuré — idéal pour des questions vérifiables et des concepts propres. OpenQuizzDB (CC BY-SA, ~7 000 questions FR) impose le partage à l'identique et sa qualité est inégale ; Open Trivia DB est anglophone. Conséquence : générateur maison à modèles, relu par échantillons ; les questions « d'anecdote » restent écrites à la main.

### D-020 · 2026-09-27 · Anti-répétition par « familles » ; silhouettes en QCM
Pourquoi : la génération produit des centaines de questions du même moule ; sans contrainte, une partie enchaîne « Quelle est la capitale… ». Colonne `questions.family`, contraintes dans `_select_questions` (pas deux fois de suite, ≤ 2 par série) et `_generate_daily_set` (une par Daily). Les silhouettes réutilisent le type `mcq` avec `payload.shape` (pas de nouveau type SQL ni d'évaluateur) ; contours Natural Earth 1:110m (domaine public), territoires éloignés retirés, micro-États exclus.

### D-021 · 2026-09-26 · Direction visuelle « Pop » (remplace « éditorial papier/encre »)
Pourquoi : le propriétaire trouvait l'app vieillotte (formes carrées, couleurs ternes) et veut des visuels qui accrochent en pub TikTok. Choix parmi trois pistes (Pop, néon sombre, éditorial modernisé) : **Pop** — fond clair, violet + jaune, couleurs vives par domaine, SF Pro Rounded, tout arrondi, rebonds. Léon, jugé inutile, est gardé à condition d'être attrayant et utile : redessiné rond et animé, il réagit aux réponses (après la réponse, jamais pendant), suit la série. S'il ne convainc pas à l'usage, il se retire sans toucher au reste (`Leon`/`LeonSays` isolés). Conséquence : les noms de tokens `paper`/`ink` restent (sens : fond/texte), `chloro` devient `sun` + `brand`.

### D-022 · 2026-09-26 · Jouer : partie classée vs entraînement libre ; thèmes multiples
Pourquoi : le propriétaire veut un jeu normal lisible — « jouer pour progresser » ou « s'entraîner comme je veux ». Classé = adaptatif, 10 questions, met à jour niveau et calibration. Libre = difficulté/nombre/chrono au choix, **niveau et calibration intacts** (échantillon biaisé par le choix), XP réduite et pas de graines (sinon farm en Débutant), erreurs suivies (utile pour réviser). Sous-thèmes conservés en choix multiple (vide = tout le domaine), seuls les thèmes à ≥ 5 questions sont proposés. Le mode « Mes erreurs » reste classé.

### D-023 · 2026-09-26 · Duels asynchrones, mêmes règles que le Daily
Pourquoi : levier viral (un défi se partage) sans imposer d'être connectés en même temps. Même série pour les deux (5 domaines, difficulté 35–65, jamais une question d'un Daily protégé), temps officiel serveur, questions dans l'ordre, score adverse révélé seulement après sa propre partie (pas d'avantage à jouer second). Expiration 48 h : celui qui a joué gagne. Les réponses comptent pour le niveau (ce sont de vraies réponses), contexte « challenge ». Défi par lien : le premier qui l'ouvre devient l'adversaire.

### D-024 · 2026-09-27 · Cote CULT, placement et parties plus exigeantes
Pourquoi : le propriétaire veut « une vraie note cohérente selon le niveau, pas une appli trop simple ». Le niveau 0–100 ressemblait à une note sur 100 et les parties visaient ~70 % de réussite. Cote façon échecs (1000 = médian, 400 points = 10 contre 1), rangs nommés, cote cachée pendant 5 parties de placement (pas doublé) pour ne jamais afficher un chiffre peu fiable ; parties classées visées à ~55 % (Défi ~40 %). Le μ interne ne change pas (calibrage, sélection, radar) : la cote n'en est qu'une lecture, donc aucune migration de données. Validé par simulation SQL. Points de partie (difficulté + vitesse) pour donner une récompense immédiate même quand le taux de réussite baisse.
**Révision 0.8.1** : le propriétaire préfère « des questions qui correspondent à l'elo » plutôt qu'un pourcentage visé, et trouve 55 % trop bas. Sélection par fenêtres d'écart de cote, légèrement sous la cote du joueur (une question pile à sa cote = 50 % par définition) : ~65 % mesurés.

### D-025 · 2026-09-28 · Objectifs du jour et de la semaine, sans inflation de graines
Pourquoi : le propriétaire veut des objectifs quotidiens et hebdomadaires, mais « pas une quantité énorme de graines, sinon ça tue le jeu ». 3 objectifs par jour (le 5 du jour toujours proposé) et 3 par semaine : au plus 9 graines par jour et 39 par semaine, soit +20 à 30 % pour un joueur assidu (qui gagne déjà 30 à 40 graines par jour) ; les aides (5 à 15 graines) gardent leur valeur. La progression est recalculée par le serveur à partir des données réelles (Daily, parties classées, réponses, erreurs corrigées, cote), donc impossible à tricher ; tirage stable par joueur et par période ; récompenses versées une fois (clés d'idempotence du ledger) à la lecture. Notifications (rappel d'objectifs, récap du dimanche) repoussées à l'ouverture du compte Apple Developer ; le récap vit dans le profil (« Mes semaines »).

### D-026 · 2026-09-28 · Brainlix et « Elo »
L'app s'appelle **Brainlix** (identifiant `app.brainlix.ios`, liens sur `brainlix.site` depuis le 29/09, domaine acheté chez Namecheap ; etudia.site n'est plus utilisé). Le 5 du jour et son logo en bâtons restent. La « Cote CULT » s'appelle **Elo** pour les joueurs ; le type Swift `CoteCULT` et les champs serveur `cote` gardent leur nom (interne, sans effet visible).

### D-027 · 2026-09-29 · L'Elo d'un domaine se gagne sur tout le domaine ; clair par défaut
Pourquoi : choisir un seul thème fort (par ex. « Capitales ») permettait de gonfler l'Elo du domaine. Une partie classée couvre donc toujours tous les thèmes ; des thèmes choisis = entraînement libre (Elo intact, XP réduite, pas de graines). « Mes erreurs » (sélection biaisée vers les points faibles) ne fait plus bouger l'Elo mais garde ses récompenses (révise D-022). Règle imposée par le serveur (`_play_pack_base`), donc aussi pour les anciennes versions de l'app. Les modes « Défi » et « Surprise » quittent l'écran Jouer (doublons de la partie rapide et de l'entraînement Expert) ; le serveur les accepte encore. L'app est **claire par défaut** quel que soit le réglage de l'iPhone ; le sombre devient un choix dans les Réglages.

### D-028 · 2026-09-29 · Coffres, arbre de Léon et trophées : des graines qui servent, sans inflation
Pourquoi : les graines n'avaient presque pas d'usage (aides à 5–15) et le parrainage en distribuait trop. L'arbre de Léon devient le puits principal, volontairement long (en fleurs en ~6 mois pour un joueur actif, arbre complet en plus d'un an) ; ses fruits donnent des objets rares et jamais des graines (pas de boucle absurde « graines → coffre → graines »). Les coffres (jamais achetables) varient les récompenses : graines, jokers, tickets d'aide, objets pour Léon. Les trophées de maîtrise lisent l'Elo classé (donc la règle D-027 : pas de gonflage par thème). Tout est tiré et vérifié par le serveur, idempotent (clés uniques), sans accès direct aux tables. Les trophées de maîtrise suivent automatiquement les domaines (trigger), le seed étant joué après les migrations.

### D-029 · 2026-09-30 · Elo v2 : départ commun, plafond par partie, difficulté resserrée
Pourquoi : l'audit a montré un Elo trop volatil (jusqu'à 8 points de niveau par réponse en placement, départ différent selon le niveau déclaré) et des parties classées tirées dans des fenêtres aléatoires (de −400 à +175). Choix validés par le propriétaire : départ à **1000** pour tous (le niveau déclaré ne sert qu'à choisir les premières questions, son effet s'éteint en 50 réponses), **plafond par partie** ±120 en placement puis ±40, une seule fenêtre classée juste sous l'Elo (≈ 65 % de réussite), 5 du jour de 44 à 56 en montée. La banque étant peu calibrée (aucune question à 10 réponses), la calibration est bridée tant qu'une question a peu de réponses. Les joueurs existants sont recalculés en rejouant leurs réponses classées (sans rejouer la calibration) ; aucune réponse n'est supprimée. Le plafond est appliqué dans `_play_submit_base`, avant trophées et variations affichées.

### D-030 · 2026-09-30 · Seconde chance plutôt qu'indices automatiques
Pourquoi : les indices « La réponse commence par… » donnaient la réponse. Le propriétaire a validé une aide qui garde de l'enjeu : réessayer une fois après une erreur, avant de voir la correction. Pour ne pas gonfler l'Elo, une réussite au 2e essai compte pour une demi-réussite (score 0,5 dans la mise à jour bayésienne, donc légère baisse sur une question facile à deviner), rapporte la moitié des points et de l'XP, ne recalibre pas la question et laisse la notion en révision. Coût 15 graines ; le ticket indice (devenu rare, seuls les indices écrits à la main restent) sert aussi de Seconde chance, sans changer le contenu des coffres.
