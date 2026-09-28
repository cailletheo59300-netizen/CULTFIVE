# Changelog

## 0.9.1 — Brainlix
- L'app s'appelle désormais **Brainlix** (nom sous l'icône, textes, admin, docs). Le 5 du jour et son logo en bâtons ne changent pas.
- Identifiant `app.brainlix.ios`, schéma `brainlix://`, liens d'invitation/ligue/duel et pages légales sur `www.etudia.site`. Réglage d'équipe Apple : `BRAINLIX_TEAM_ID`.
- Serveur : migration 0019 (texte du succès « premier ami », tâche planifiée `brainlix-daily-maintenance`).
- La **« Cote CULT » s'appelle « Elo »** dans l'app (accueil Jouer, domaines, fin de partie, profil, partage, célébrations) et dans l'objectif « Gagne 30 points d'Elo dans un domaine » (migration 0020). Calcul, rangs et placement inchangés.

## 0.9.0 — objectifs et récap
- **Objectifs du jour** (3, dont toujours « Fais le 5 du jour ») et **de la semaine** (3, du lundi au dimanche) : carte « Objectifs » sur l'accueil (onglets Jour/Semaine, jauges, récompense, bonus, temps restant), célébration quand un objectif est rempli. Récompenses modestes : 15 XP + 2 graines par objectif du jour (+10 XP + 3 graines pour les trois), 50 XP + 8 graines par objectif de la semaine (coffre de 15 graines). Progression calculée par le serveur, impossible à tricher.
- **Profil** : section **« Mes semaines »** (parties, réponses, % de réussite, moyenne au 5 du jour, variations de cote par domaine, objectifs, erreurs corrigées) et **historique du 5 du jour** (score, % de bonnes réponses, classement « top X % »), en résumé sous le calendrier et en feuille détaillée.
- Serveur : migration 0017 (`user_quests`, `quests_overview`, `weekly_recap`, `daily_history` avec `rate` et `percentile`), tests `90_quests.sql`. Sélection : le thème cède avant la variété des familles (plus de parties avec deux questions du même moule).

## 0.8.2 — algo plus juste
- **Hasard pris en compte** : un QCM à 4 choix se réussit 1 fois sur 4 sans rien savoir. Une bonne réponse devinable fait moins monter la cote, une erreur devinable la fait davantage baisser ; les questions se calibrent pareil ; les fenêtres visent les chances réelles.
- **Thèmes équilibrés** dans chaque partie de domaine (2 par thème sur 10 en Géographie, au lieu de parties dominées par « Pays & villes »).
- **Révision espacée** des erreurs (1 j, 3 j, 7 j, 21 j) ; une révision due se glisse dans les parties classées du domaine et dans « Mes erreurs ».
- Migration 0016, tests `80_algo.sql`, simulation : 66 % de réussite, niveau retrouvé à 1,8 point près.
- **Qualité de la banque** : contrôles automatiques dans `build-seed.mjs` (doublons exacts et quasi-doublons, Vrai/Faux entre 40 et 60 % de « vrai ») ; 23 doublons retirés ; 13 Vrai/Faux inversés (33/33) ; le générateur Wikidata écarte les réponses devinables depuis l'énoncé (« Guinée → Franc guinéen », « Lettonie → Letton » : ~115 questions).
- **+540 questions** : 110 de calcul générées (réponses exactes, méthode, indice) et ~430 écrites à la main, avec indice, dans les thèmes les plus maigres. **Tous les thèmes ont désormais au moins 40 questions.** Banque : 4 327.
- **Indices pour ~80 % des questions** (au lieu d'une seule) : initiale de la réponse, avec le nombre de lettres si besoin ; fourchette pour les nombres et les années. Les indices écrits à la main restent prioritaires.

## 0.8.1 — Jouer compact, questions à ta cote
- **Écran Jouer** repensé : grande carte « Partie rapide », Surprise / Défi / Erreurs en pastilles sur une ligne, domaines en grille de 3 cases pleines de couleur (pictogramme, cote + rang ou placement, ★ favoris). 4 rangées au lieu de 6, cote globale en haut.
- **Questions choisies par écart de cote** (migration 0015) : surtout un peu sous ta cote ou pile à ta cote, quelques-unes plus accessibles ou au-dessus. Réussite ≈ 65 % en partie classée (au lieu de 55 %), Défi ≈ 45 %. Simulation `70_rating.sql` mise à jour.

## 0.8.0 — Cote CULT
- **Cote CULT** par domaine et globale (1000 = niveau médian, rangs Curieux → Encyclopédie). Cachée pendant **5 parties de placement** (« Placement 2/5 »), puis dévoilée avec célébration ; nouveau rang célébré. Affichée sur les tuiles Jouer, la page domaine (courbe en cote), le profil (carte Cote CULT), la feuille de choix, le résultat du Daily et la carte de partage.
- **Parties plus exigeantes** : parties classées visées à ~55 % de réussite (au lieu de ~70 %), Défi ~40 %. Placement plus rapide (pas doublé sur les 50 premières réponses).
- En partie : pastille de difficulté (Facile · Moyen · Difficile · Très difficile), **ordre adaptatif** (plus dur après 3 bonnes réponses, plus accessible après 2 erreurs), **points** par question (difficulté + vitesse, « +140 pts »), total et variation de cote au bilan (« 1 342 +18 · Érudit »).
- Serveur (migration 0014) : `_cote`, `_rating_json`, bandes plus exigeantes, `play_pack` enrichi (`difficulty`, `expected`), `play_submit` avec `points` et `ratings`, `skills_overview`/`domain_stats` avec cote et placement. Tests `70_rating.sql` avec **simulation** de trois joueurs (convergence vérifiée).
- Contenu : 105 questions **expertes** (66–85) sur tous les thèmes ; thèmes Wikidata trop resserrés étalés ; rapport `docs/CALIBRATION.md`. Banque : 3 975.
- Démo : cote, placement et points simulés (Calcul, Français et Géographie sont à 4/5 : la prochaine partie classée dévoile la cote).

## 0.7.0 — thèmes et contenu
- **Duels** : défier un ami (éclair à côté de son nom) ou n'importe qui par lien (`www.etudia.site/d/CODE`), sur les mêmes 5 questions de 5 domaines ; chacun joue quand il veut (48 h) ; temps officiel serveur ; score adverse caché tant qu'on n'a pas joué ; vainqueur au score puis au temps (+20 XP, +5 graines). Écrans face-à-face, résultat « VS », section Duels dans Amis. Migration 0013, tests `60_duels.sql`. Démo : adversaire simulé.
- **Admin web** (`admin/index.html`) : tableau de bord par thème, liste filtrable et triable (difficulté, réussite, signalements), éditeur par type de question, publication/désactivation, 5 du jour (générer, remplacer), signalements.
- **Signaler une question** dans l'app (réponse fausse, ambiguë, plus à jour, faute, autre) → « à revoir » côté admin. Migration 0012 (`question_reports`, `report_question`, `admin_questions` triable, `admin_resolve_reports`, thèmes retirés inactifs).
- Thèmes réorganisés : 3 à 5 par domaine, chacun ≥ ~20 questions. Histoire par époques (date → période), Géographie en 5 thèmes, Logique + Énigmes, nouveaux thèmes Mythologie, Architecture, Champions, Acteurs, Animation, Entreprises & marques, Vie marine, Planète & climat.
- +727 questions : Wikidata (lunes, points culminants, décennies de films, castings), 43 suites logiques calculées, ~400 questions écrites à la main. Banque : 3 870.
- Démo : 8 questions par thème, liste des thèmes à jour.

## 0.6.0 — le jeu normal, cohérent
- Toucher un domaine ouvre le **choix de partie** : **partie classée** (10 questions adaptées, le niveau bouge) ou **entraînement libre** (5/10/20/30 questions, chrono 20 s optionnel, difficulté Mon niveau/Débutant/Intermédiaire/Expert, niveau inchangé, moitié d'XP, pas de graines, erreurs suivies).
- **Thèmes** : tout mélanger, un seul ou plusieurs (sous-thèmes jouables uniquement, ≥ 5 questions).
- Partie : écran d'intro aux couleurs du domaine, anneau de chrono, série « 🔥 3 d'affilée », bilan avec « Ce que tu as appris » (questions ratées + bonne réponse), Rejouer / Corriger mes erreurs / Autre domaine.
- Serveur (migration 0011) : `play_pack(…, p_ranked, p_level, p_subdomains)`, `_record_attempt(…, p_ranked)` (niveau et calibration intacts hors classé), une question par famille et par partie tant que possible. Tests `50_play_modes.sql`.
- Démo fidèle : vraie banque par domaine (`play_bank.demo.json`, `scripts/gen-demo-bank.sh`), jamais deux fois la même question dans la séance, difficulté, erreurs, aides, niveaux et stats par domaine simulés.
- Build Appetize : un seul zip (l'artefact contient directement `CultFive.app`).

## 0.5.1 — petits domaines
- Musique, sport, technologie enrichis via Wikidata : familles d'instruments, origine et décennie des groupes, Coupes du monde (vainqueur, hôte), villes des JO d'été et d'hiver, inventeurs ↔ inventions (listes relues).
- 96 questions écrites à la main : nature (classes d'animaux, petits et cris, plantes), logique (suites, horloges, âges, syllogismes), informatique, règles du sport, musique classique.
- Banque : 3 143 questions (musique 207, sport 110, tech 81, nature 46, logique 30).

## 0.5.0 — design « Pop »
- Nouvelle identité : fond clair lavande, violet électrique + jaune soleil, couleur vive et pictogramme par domaine, SF Pro Rounded gras, tout arrondi (cartes, pilules), boutons « jouet » qui s'enfoncent, rebonds, secousse sur une erreur, confettis. Nouvelle icône.
- Léon redessiné (rond, grands yeux, joues roses) et animé : attrape la bonne réponse avec sa langue, grisaille sur une erreur, arc-en-ciel sur un sans-faute, queue qui s'enroule avec la série, salue à l'accueil avec une bulle.
- Écrans refaits : question (voile de couleur du domaine, pastilles, progression en pilules), résultat du Daily (dégradé violet, score qui monte, célébrations), accueil (grande carte du jour), Jouer (cartes de modes, tuiles de domaines), domaine, profil (radar de culture), onboarding (ronde de domaines), barre d'onglets flottante, amis, ligues (podium).
- Célébrations : trophée, erreur corrigée, niveau passé (Daily et parties).
- Partage : modèles Violet / Soleil / Blanc ; nouvelles cartes « radar de culture » et « question du jour » (sans la réponse, depuis la revue).

## 0.4.0
- Nouveaux formats de géographie : localiser une capitale sur la carte, monnaie, langue officielle, site UNESCO → pays, silhouette du pays (nouvel affichage dans l'app).
- Anti-répétition : familles de questions (migration 0010), variantes de formulation. Banque : 2 716 questions.

## 0.3.1
- Daily : le créneau « Surprise » tire d'abord un domaine au hasard (migration 0009, testé sur 60 jours).
- Explications Wikidata enrichies (contexte des batailles, présentation des auteurs, pays et population pour les capitales).
- +80 questions écrites à la main (Calcul 40, Français 40), types variés. Banque : 1 958.

## 0.3.0 — session 2 (suite)
- Générateur Wikidata (CC0) : 1 613 questions (géographie, histoire, sciences, arts, cinéma), cache versionné, règles de français, garde-fous, relecture par échantillons. Banque : 1 886 questions.
- `CLAUDE.md` : règles de travail (validation des étapes avant de coder, captures sur demande uniquement).

## 0.2.0 — session 2 (2026-09-26)
- Mode démo (Debug uniquement) sur réponses RPC réelles enregistrées ; build simulateur pour Appetize.io ; 16 captures automatiques (clair/sombre) dans `docs/screenshots`.
- Contenu : +120 questions (273), vague 2 riche en classements, associations, vrai/faux et calcul.
- Trait de cinq : une réponse ratée = trait court et estompé (plus de pointillés).
- Profil : les niveaux fiables (≥ 10 réponses) en tête de « Ce que tu sais ».

## 0.1.0 — session 1 (2026-09-26)
- Phase 0 : cahier des charges analysé, architecture, décisions, design system, schéma de données.
- Backend Supabase complet et testé : Daily autoritaire (série commune, temps serveur, percentile honnête, série + jokers, cas limites minuit/fuseau/expiration/double soumission), adaptatif (Rasch + bayésien), calibration bornée, erreurs par concept, ledger XP/graines, trophées, Jouer (packs, soumission idempotente, aides), amis, parrainage anti-abus, ligues, admin, RLS.
- Contenu : 153 questions curées sur 12 domaines, pipeline JSON → seed validé.
- Package `CultFiveCore` : modèles, évaluation, pavé numérique, client Supabase maison, file hors-ligne, tests + contrats JSON.
- App SwiftUI : design system (trait de cinq, Léon, New York), onboarding jouable, 5 du jour, résultat, revue, Jouer (5 modes, domaines, stats), amis, ligues, profil, réglages, suppression de compte, partage 9:16, notifications locales.
- CI GitHub : SQL (Postgres 16), `swift test`, build + tests iOS.
