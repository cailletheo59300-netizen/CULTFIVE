# Changelog

## 0.19.0 — la Recharge des coffres
- **Recharge** : on touche 3 fois le coffre ; il tremble de plus en plus fort dans un halo à sa couleur, des étincelles jaillissent, et il peut **monter de rang** (bannière « Amélioré : Coffre en or ! », éclat, vibration). Tirage fait une seule fois par le serveur à l'ouverture : bois → argent 25 %, argent → or 20 %, or → Savant 5 %.
- **Coffre Savant** (violet, constellation) : 120–160 graines, un joker, 2 tickets, un objet garanti ; au premier, le **Mortier de savant**, objet exclusif jamais vendu.
- **Nouveau dessin des coffres** : écusson rond marqué de l'étincelle Brainlix, couvercle en dégradé, léger balancement au repos, halo par rareté.
- Compatibilité : le rang d'origine reste dans `tier`, le rang obtenu est dans `final_tier` (anciennes versions de l'app inchangées). Migration 0029, tests `99_chest_recharge.sql`.

## 0.18.0 — placement lisible, 5 du jour plus fluide
- **Placement en 5 carrés** : dans le Profil, tous les domaines apparaissent (même jamais joués) avec 5 carrés à leur couleur, un par partie classée, et « 2/5 parties · encore 3 pour découvrir ton rang ». Mêmes carrés sur l'accueil (domaine à travailler), l'écran Jouer et la fin de partie (« Encore 2 parties classées en Histoire… »), célébration « Rang découvert : Érudit ! » à la 5e.
- **En-tête du Profil** : l'Elo global ne compte que les domaines placés ; sinon, les carrés du domaine le plus avancé et « Domaines placés : 3 sur 12 ».
- **« Comment marche l'Elo »** (bouton « ? » dans « Ce que tu sais ») : 5 parties pour ton rang, départ à 1000, plafonds par partie, parties qui comptent, liste des rangs.
- **5 du jour** : la question s'efface dès « Question suivante » ; le score final est préparé pendant la lecture de la dernière correction (plus de chargement à la fin). Le chrono officiel ne change pas (pas de préchargement des questions, donc aucune lecture en avance possible).

## 0.17.0 — Seconde chance
- **Seconde chance** (parties Jouer, jamais au 5 du jour) : après une mauvaise réponse, avant la correction, « Seconde chance » (15 graines ou un ticket indice) ou « Voir la réponse ». La réponse déjà tentée est retirée (QCM, carte). Juste au 2e essai : moitié des points et de l'XP ; en partie classée, **demi-réussite** pour l'Elo ; la question n'est pas recalibrée et la notion reste à revoir. Pas proposée sur un Vrai/Faux ni un choix à 2 options.
- Le serveur ne retient le 2e essai que si la Seconde chance a été payée et que le 1er essai est faux (migration 0028, tests `98_second_chance.sql`).
- Les tickets « indice » servent aussi de Seconde chance.

## 0.16.0 — Elo plus juste, aides plus réactives
- **Elo v2** (migration 0027) : tout le monde part de **1000** (le niveau choisi à l'inscription règle seulement la difficulté des premières questions, pendant 50 réponses) ; **plafond par partie** : ±120 pendant le placement (50 premières réponses du domaine), ±40 ensuite ; pas par réponse réduit ; partie classée dans une **fenêtre étroite** (questions un peu sous ton Elo, ≈ 65 % de réussite), repli vers la question la plus proche quand un domaine manque de questions.
- **5 du jour** : difficultés resserrées (44 → 56), rangées de la plus accessible à la plus dure.
- **Calibration des questions** prudente : ±5 autour de la difficulté d'origine avant 20 réponses, ±15 avant 50.
- **Joueurs existants** : Elo recalculé à partir de leurs réponses classées, dans l'ordre et à leur date (courbes conservées), avec les nouvelles règles. Objectif « Gagne 30 points d'Elo » et récap : un domaine jamais joué part de 1000.
- **Aides en jeu** : réaction immédiate (graines et tickets décomptés tout de suite, rendus en cas d'échec), plus de double débit en tapant deux fois ; compteur de graines à côté des boutons d'aide ; le bilan de partie s'affiche aussitôt (« Calcul de ton Elo et de tes récompenses… »).
- **Indices** : les indices « La réponse commence par… » (qui donnaient la réponse) sont retirés ; seuls les indices écrits à la main restent (migration 0026).
- **Rapidité** : le fuseau horaire n'est plus envoyé qu'en cas de changement, en arrière-plan, et vérifié sans parcourir la liste des fuseaux (0,8 s → instantané) ; profil et progression chargés en parallèle.
- **Graine** : nouvelle icône (graine dorée avec une pousse) à la place de la feuille.

## 0.15.0 — onboarding soigné, Tenue unique, ouverture des coffres
- **Onboarding** : exactement 3 questions (un bug en servait 5), tirées d'une **banque dédiée de 24 questions** choisies à la main : une question qui surprend, une énigme connue, un « le savais-tu ? » (`content/questions/onboarding.json`, migration 0025). Plus de barre pendant les questions ; ensuite « Étape 1 sur 4 · Ton niveau », « Tes domaines », « Ton pseudo », « Ton compte ».
- **Profil allégé** : les médailles de maîtrise (Bronze → Diamant) sont sur les cartes « Ce que tu sais », à côté de l'Elo ; la vitrine ne garde que les trophées d'exploit.
- **Tenue unique** (écran Léon, onglets Arbre / Tenue) : garde-robe et boutique réunies, Léon en cabine d'essayage, une ligne par emplacement (4 cases + « + N »), cases teintées selon l'origine (coffres, fruits, arbre), un seul bouton Porter / Acheter / origine, vitrine du jour en bandeau, tenue au hasard.
- **Ouverture des coffres** : tremblement qui monte avec les vibrations, éclat de lumière, rayons tournants ; les récompenses sortent une par une en grandes cartes dessinées (graines qui défilent, tickets, bouclier de joker, Léon qui porte son objet), puis récapitulatif.

## 0.14.0 — Léon : boutique, formes, cabine d'essayage
- **Boutique de Léon** (graines uniquement, jamais d'argent réel) : 12 couleurs de peau (200–600), 4 motifs (rayures, pois, étoiles, arc-en-ciel ; 800–1 500), 12 objets (casquette, bonnet, chapeau de magicien, couronne, lunettes de soleil, masque de héros, médaille, collier de fleurs, sac à dos, ailes, aura étoilée, bulles ; 300–1 200). **Vitrine du jour** : 3 articles par joueur, le premier à −30 %. Les objets des coffres et des fruits ne sont jamais vendus.
- **Cabine d'essayage** : chaque article s'essaie sur Léon avant l'achat ; acheté, il est porté aussitôt.
- **Formes de Léon** liées à l'arbre : Bébé (départ), Jeune (Jeune plant), Adulte (Arbre), Sage (en fleurs, feuilles lumineuses). La plus avancée s'affiche d'office ; on peut revenir à une ancienne.
- **« Voir toutes les étapes »** : frise de l'arbre (6 étapes + 4 fruits) avec les seuils, les récompenses et la forme de Léon, en silhouette tant qu'elles ne sont pas atteintes.
- **Garde-robe** : forme, peau, motif, chapeau, yeux, cou, dos, effet ; bouton « Au hasard ».
- Serveur : migration 0024 (`shop_overview`, `shop_buy`, formes), tests `97_leon_shop.sql`.

## 0.13.0 — lot 5 : ligues, onboarding, finitions
- **Ligues** : explication en 4 étapes illustrées (au premier passage, puis bouton « ? »), fin de période en clair (« Se termine dimanche 7 mars à minuit · dans 3 jours »), coffres du podium affichés à côté des 3 premiers, carte « Tu as fini 2e : coffre en argent ! » sur la période précédente.
- **Coffres du podium** (serveur, migration 0023) : or / argent / bois pour les 3 premiers à la fin de chaque période, si la ligue compte au moins 4 joueurs actifs et le joueur au moins 3 jours joués (10 pour un mois). Tâche planifiée horaire, versement de secours à l'ouverture des ligues, un seul coffre par ligue et par période.
- **Onboarding** : barre de progression et retour ; écran « On fait connaissance » qui explique les 3 questions ; question « 1 sur 3 · pour régler ton niveau » ; résultat (« 2 sur 3, pas mal du tout ») avec le niveau proposé selon le score ; conseil de choisir au moins 3 domaines ; pseudo avant le compte, avec « Proposer un pseudo » ; coffre d'or de bienvenue à ouvrir, puis « Voilà comment ça marche » (5 du jour, coffres, arbre de Léon).
- **Rappel** : proposé une seule fois, après un 5 du jour (heure au choix, autorisation de l'iPhone demandée seulement après « Oui »).
- **Site** : page d'aide complétée (coffres, graines et arbre, trophées, ligues, jokers de série, règle de l'Elo).

## 0.12.0 — lot 4 : coffres, arbre de Léon, tenue, trophées (app)
- **Coffres** : pastille 🎁 sur l'accueil, carte « coffres à ouvrir » en fin de partie, sur l'écran Léon et le Profil. Ouverture en plein écran à la chaîne : le coffre (dessiné en code, bois / argent / or) tremble, s'ouvre dans un éclat, le contenu apparaît ligne par ligne.
- **L'arbre de Léon** (Profil → Léon ou la carte « L'arbre de Léon ») : l'arbre dessiné à chaque étape puis ses fruits, Léon qui grandit avec lui, jauge vers la prochaine étape, boutons Nourrir (+10, +50, Tout), célébration et coffre à chaque étape.
- **Tenue de Léon** : 12 objets dessinés en code (béret, chapeau de fête, casque, lunettes rondes / étoiles, écharpe, nœud papillon, peau coucher de soleil ; fruits : couronne de feuilles, monocle, cape étoilée, Léon doré). Léon porte sa tenue partout dans l'app.
- **Trophées** : vitrine du Profil avec la maîtrise par domaine (Bronze / Argent / Or / Diamant, Elo et prochain palier) et les 13 exploits (détail au toucher).
- **Défis** remplacent « Objectifs » ; le bonus des trois défis montre son coffre.
- **Tickets d'aide** : affichés sur les boutons d'aide (« 🎟️ 1 ») et utilisés avant les graines.
- **Sons** discrets synthétisés (bonne / mauvaise réponse, coffre, récompense), muets en mode silencieux ; réglage « Sons » dans Réglages → Jeu.

## 0.11.0 — lot 3 : coffres, arbre de Léon, trophées (serveur)
- **Coffres** bois / argent / or, jamais achetables, contenu tiré par le serveur à l'ouverture : graines, jokers de série, tickets d'aide (50/50, indice), objets pour Léon. Sources : 3 défis du jour (bois), 3 défis de la semaine (argent), chaque niveau d'XP (bois ; argent tous les 5 ; or tous les 10), trophées, étapes de l'arbre (or), paliers de parrainage.
- **Arbre de Léon** nourri de graines : Graine → Pousse (150) → Jeune plant (600) → Arbuste (1 800) → Arbre (4 000) → en fleurs (9 000, ~6 mois), puis un fruit tous les 2 500 graines (4 objets rares, arbre complet à 19 000).
- **12 objets pour Léon** (8 dans les coffres, 4 fruits) et tenue par emplacement. **Tickets d'aide** utilisés avant les graines.
- **Trophées** : 13 exploits (+ Placé, Sans-faute classé, Globe-trotter) et 48 de maîtrise (Elo 1 050 / 1 200 / 1 350 / 1 500 par domaine). Chaque trophée donne un coffre au lieu de graines.
- **Parrainage rééquilibré** : 30 graines pour l'invité (100), 50 pour le parrain (150), paliers en coffres.
- Joueurs existants : arbre de départ selon l'XP (au plus « Jeune plant »), trophées de maîtrise déjà mérités débloqués sans coffre, un coffre d'or de bienvenue.
- Fin de partie : les trophées s'affichent par leur nom. Accueil : la carte Défis annonce le coffre des trois défis.
- Serveur : migration 0022, tests `95_gamification.sql`. L'affichage (ouverture des coffres, écran Léon et arbre, vitrine des trophées) arrive au lot 4.

## 0.10.1 — accueil : bloc « Aujourd'hui »
- Sous la carte du jour (inchangée), un seul bloc **« Aujourd'hui »** remplace les cartes à icônes génériques : erreurs à revoir en gros chiffre, domaine à travailler en bandeau à sa couleur (Elo ou placement), ligue avec **ta place** (« 3e sur 8 · fin dans 3 j »).
- La série n'est plus affichée deux fois : la carte « Série » disparaît, les jokers rejoignent la pastille 🔥 du haut.
- Barre du bas : la marge est appliquée par chaque page défilante (onglets, fiche domaine, ligue, réglages) ; plus rien de caché.

## 0.10.0 — lot 1 : clair, réglages, règle de l'Elo
- **Apparence claire par défaut**, même si l'iPhone est en sombre (plus de menus noirs). Réglage « Clair / Sombre / Comme l'iPhone ». Les écrans violets immersifs ne changent pas.
- **Barre du bas** : elle ne cache plus les dernières lignes (Jouer, 5 du jour, Amis, Profil, fiches domaine, ligues), quelle que soit la taille d'écran ou de texte (hauteur mesurée).
- **Réglages** : vraie page Brainlix ouverte depuis le Profil. Pseudo, apparence, notifications, vibrations, tranche d'âge, compte, aide et pages légales, version. Enregistrement immédiat (plus de bouton « OK » qui perdait les changements).
- **Règle de l'Elo** : une partie classée couvre toujours tous les thèmes du domaine. Choisir des thèmes = entraînement libre. « Mes erreurs » ne fait plus bouger l'Elo mais garde ses récompenses pleines. Appliqué aussi par le serveur (migration 0021, y compris pour les anciennes versions de l'app).
- **Jouer** : modes « Défi » et « Surprise » retirés (pour plus dur : entraînement libre en Expert). « Revoir mes erreurs » n'apparaît que s'il y en a.
- **Avant la partie** : nouvel écran de lancement (type de partie, nom du domaine en grand, promesse, thèmes choisis, trois repères questions / difficulté / Elo en jeu) et compte à rebours 3-2-1 sur « Go » (sauté si « Réduire les animations »).

## 0.9.5 — questions difficiles
- +144 questions de niveau 70 à 85 (`content/questions/lot_v7_hard.json`) pour les thèmes qui en manquaient (français, Antiquité, Moyen Âge, sciences, corps humain, nature, architecture, mythologies, musique classique, sport, tech, cinéma, géographie, suites logiques) : **5 293 questions**. Doublons avec les questions « expert » et Wikidata retirés.

## 0.9.4 — +822 questions
- **5 149 questions** (4 327 avant), tous les thèmes ≥ 52 (40 avant).
- Calcul : générateur restructuré en modèles réutilisables ; la première série (`gcalc-*`) reste identique, une seconde (`gcalb-*`) ajoute 180 questions et de nouveaux modèles (addition/soustraction autour d'un nombre rond, ×125, ×9/99/999, doubler-diviser, retrouver le total, taux d'évolution, TVA, fraction en %, produit de fractions, prix au kilo, somme et différence, piquets).
- ~570 questions écrites et relues (`content/questions/lot_v6_*.json`) : français (expressions, synonymes, orthographe, grammaire, vocabulaire), Antiquité et Moyen Âge, physique, biologie, corps humain, espace, terre et climat, vie marine, plantes, animaux, architecture, mythologies, musique classique, champions, règles, football, marques, informatique, énigmes, raisonnement, animation. Faits stables uniquement (pas de records en cours), doublons de sens retirés après comparaison avec toute la banque.

## 0.9.3 — site brainlix.site
- Site `site/` (statique, hébergé sur Vercel, domaine **brainlix.site**) : accueil, confidentialité, conditions d'utilisation, mentions légales, aide ; page d'atterrissage des liens `/i/`, `/l/`, `/d/` (ouvre l'app ou invite à l'installer) ; `apple-app-site-association` (liens universels) ; `app-ads.txt` (prêt pour les pubs).
- App : liens d'invitation, de ligue et de duel et pages légales sur `https://brainlix.site`, liens universels `applinks:brainlix.site`, contact support.
- E-mails : contact `bonjour@brainlix.site` (redirection ImprovMX), envoi des codes de connexion par Resend (domaine brainlix.site vérifié, SMTP Supabase).

## 0.9.2 — TestFlight
- Équipe Apple `BM85BF2WVQ` dans le projet ; déclaration de confidentialité Apple (`PrivacyInfo.xcprivacy` : aucun pistage, e-mail, identifiant, données de jeu et d'usage, identifiant d'appareil haché, pour le fonctionnement de l'app).
- Workflow manuel **TestFlight** : archive Release signée automatiquement avec la clé App Store Connect API, contrôles (identifiant, confidentialité, pas de fichiers démo), envoi sur App Store Connect.

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
- **Duels** : défier un ami (éclair à côté de son nom) ou n'importe qui par lien (`brainlix.site/d/CODE`), sur les mêmes 5 questions de 5 domaines ; chacun joue quand il veut (48 h) ; temps officiel serveur ; score adverse caché tant qu'on n'a pas joué ; vainqueur au score puis au temps (+20 XP, +5 graines). Écrans face-à-face, résultat « VS », section Duels dans Amis. Migration 0013, tests `60_duels.sql`. Démo : adversaire simulé.
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
