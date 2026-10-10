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

**1.1 — partie A (app seule, sans toucher au serveur ; version 1.1.0, à tester sur TestFlight)** — maquettes validées par le propriétaire (coffre 3D, objets 3D, rangs 3D, arbre 2D, célébrations, petites icônes) :
1. ✅ Icônes 3D (coffres fermés/ouverts, graines, flamme, joker, tickets, arrosoir, emblèmes de rang, coupe) rendues par `scripts/icons/render.mjs` dans `Assets.xcassets/Icons`, utilisées partout.
2. ✅ Ouverture des coffres : couvercle 3D image par image (`ChestOpening/`), cartes de rareté qui se retournent.
3. ✅ Célébrations en plein écran à la suite (`CelebrationSequence`) : niveau, rang, trophée, record de série, défi.
4. ✅ Arbre de Léon vivant (décor animé, graines qui volent, rebond, jauge en 6 traits). Carte « Arrosoir » : partie B.
5. ✅ « Mon sac » (touche les graines de l'accueil).
6. ✅ Touche « − » toujours présente sur le pavé numérique.
7. ✅ Aides en grille de 2 colonnes.
8. ✅ Pastille de difficulté retirée.
9. ✅ Emblèmes de rang 3D (profil, Jouer, domaine, explication de l'Elo) ; seuils actuels jusqu'à la partie B.

## À faire après la publication de la 1.0 (partie B — serveur, avec le feu vert du propriétaire)
Liste tenue à jour à chaque nouvelle demande. Rien de ceci ne touche la production tant que la 1.0 n'est pas publiée.

**Coffres et objets**
- [ ] Fréquence des coffres : niveaux 2 à 9 → graines, coffre d'argent au niveau 5 ; dès le niveau 10 → un coffre par niveau ; petits trophées → graines, gros trophées → coffres.
- [ ] Coffre boosté par une pub : monte **toujours** d'un rang (bois → argent → or → Savant), graines +50 %, peut encore monter par chance. Bouton : « Amélioration garantie ».
- [ ] Arrosoir : objet épique des coffres ; pendant 4 h, les dons à l'arbre comptent double. Afficher alors sa carte sur l'écran de l'arbre (prévue dans la maquette validée).
- [ ] Pubs de « Mon sac » : 50/50 et indice 1 par jour chacun ; arrosoir 1 par semaine ; joker 1 par semaine si moins de 2 (la pub « Sauve ta série » reste à part). Boutons cachés tant que le serveur ne les propose pas.

**Elo et niveau des questions**
- [ ] Elo de départ 500, seuils des rangs 600 / 750 / 900 / 1 050 / 1 200 ; joueurs actuels décalés sans perte de place relative ; trophées de maîtrise redécoupés.
- [ ] La 1.1 lit les seuils des rangs depuis le serveur ; bascule de l'Elo seulement une fois la 1.1 publiée ; message « mets à jour l'app » pour la 1.0. Textes « tout le monde part de 1 000 » à changer.
- [ ] Recalibrer toute la banque (≈ 11 points trop optimiste) puis recalcul hebdomadaire avec les vraies réponses.
- [ ] Réévaluer les questions avec la grille à exemples (ex. capitales). Beaucoup de grands classiques faciles existent déjà mais sont notés trop durs.
- [ ] Mélange dans chaque partie classée : ≈ 3 accessibles, 5 au niveau, 2 qui piquent ; viser ≈ 70 % de réussite.

**Contenu**
- [ ] Déployer les questions accessibles en production : lot 1 (Histoire, Géographie, Sciences : 120) et lot 2 (Arts 33, Calcul 37, Cinéma 24, Musique 19). lot 3 (Sport 37, Nature 40, Technologie 40, Français 43, Logique 23) et lot 4 (Histoire 25, Géographie 31, Sciences 22, Cinéma 24, BD et contes 13, Musique 8). Total accessible : 599 (dont lot 5 : Calcul du quotidien 36, Logique et énigmes 24).
- [x] Nouveaux types de réponses codés (serveur 0038–0039, app 1.1, tests SQL et Swift) : compteur, frise, jauge, proportions, lettres mélangées, mots dans l'ordre, choix d'images. Toujours juste ou faux ; marge annoncée avant (🎯), zone visée en direct, correction « Pile ! / Juste, dans la marge / Presque… / Raté » avec bonne réponse, réponse et écart ; « Pile ! » = +5 graines.
- [x] Règles validées : 5 du jour = 5 thèmes, dont 1 ou 2 questions d'un nouveau type (jamais deux du même, pas le type de la veille) ; parties classées = au plus 1 nouveau type par partie, environ une partie sur deux ; duels et ligues = classiques. App 1.0 : remplaçant classique (en-tête `x-brainlix-types`).
- [ ] **À déployer après la publication de la 1.1** : migrations 0038–0041 + seed (questions accessibles et nouveaux types). L'app 1.0 continue de marcher grâce aux remplaçants.
- [ ] Contenu des nouveaux types (910 questions dans le seed, non déployées). Reste : images des tableaux (domaine public, Wikimedia Commons ; en brouillon tant qu'elles manquent), silhouettes dessinées pour les proportions (émojis en attendant), puis en écrire d'autres.
- [x] Lot 2 codé (serveur 0040–0041, app, tests) : le compte est bon (60), mot mystère en 3 indices (40, +3 / +1 graine), épingle sur la carte (65), tri express (36) et pyramide des âges (19). Abandonnés : rébus, lequel d'abord, distance sur la carte, horloge, thermomètre, boussole, vases communicants. Encore en réserve : assemble le drapeau, le mot manquant, la balance, le cadenas à code.
- [x] Règle confirmée : les nouveaux types ont une difficulté comme les autres et comptent pour l'Elo ; ils apparaissent dans les parties classées, mais davantage dans le 5 du jour.

**Album de cartes + pass de saison (piste qui pourrait remplacer l'arbre, maquette à valider)** : https://claude.ai/artifact/GeKi7h9BogWu7SrFQ88e7c
- [ ] Décidé avec le propriétaire : la monnaie « graines » devient « neurones » (nom et icône seulement ; en interne et côté serveur, rien ne change). Album : une page par sous-thème (49, d'après les `concept` du contenu : domaine.sous_thème.notion), 12 à 15 cartes par page (environ 650 cartes, chacune regroupe plusieurs questions), carte emblème de la page bronze → argent → or → diamant selon la maîtrise du sous-thème.
- [ ] Maquette : carte du jour sur l'accueil (silhouette + indice), pochettes de 5 cartes (au moins 1 rare ; chances affichées ; légendaire garantie à la 40e), cartes voilées activées par une question, doublons → neurones, étoiles de maîtrise qui pâlissent sans révision, atelier (fabriquer une carte avec des neurones), collections spéciales multi-domaines, vitrine. Pass : un mois, 40 paliers, thème (octobre : monstres et légendes), missions de la semaine, collection de saison de 24 cartes, gratuit (partie payante possible après la publication).
- [x] Léon reste la mascotte et devient le guide de l'album ; garde-robe et cosmétiques de Léon supprimés, seulement des tenues de saison posées par l'app (D-040). À retirer quand on codera : LeonWardrobe et les tenues dans les coffres et le sac.
- [x] Coffres gardés (niveaux), pochettes par série choisies par le joueur, toutes de même valeur (D-041).
- [ ] Idées de cosmétiques autour des cartes, pour le pass et plus tard le pass payant : cadres (matières, domaines, saisons), finitions (holographique, effet 3D quand on penche le téléphone), illustrations alternatives, cartes animées, éditions limitées numérotées, designs et façons d'ouvrir les pochettes, révélation selon la rareté, couvertures d'album, autocollants, socles de vitrine, titres. Règles : rien de payant ne fait gagner au quiz, toutes les cartes restent gagnables gratuitement, cosmétiques vendus à prix fixe plutôt qu'au hasard.
- [x] Style des cartes validé par le propriétaire : https://claude.ai/artifact/6dbuCP7bKCnKs991zB6uuC — « carte-affiche » sans emoji : fond dessiné par domaine et unique par carte (courbes de niveau, plan technique, gravure, papier millimétré, ondes), sujet au trait d'une seule encre (contours de pays, monuments, objets ; portraits gravés du domaine public), chiffre clé en grand (1789, 8 849 m, 440 Hz), nom en grande typo, phrase courte ; rareté = matière du cadre (crème, métal bleu, vernis irisé, feuille d'or) ; relief quand on penche l'iPhone. Cartes fabriquées par un script à partir d'une fiche par carte.
- [x] Étape 1 commencée : fiches des 3 pages tests dans `content/album/` (Moyen Âge 18 cartes, Espace 15, Relief 14 ; chaque notion rangée dans une seule carte), vérifiées par `node scripts/check-album.mjs`. Planche : https://claude.ai/artifact/8VfykttC2iSD81ej55AChx. Rareté laissée vide (D-042). Chiffres clés à relire par le propriétaire.
- [ ] Contenu à corriger : 18 notions « Époque de … » de la Renaissance (Luther, Magellan, Michel-Ange…) sont rangées dans `history.middle_ages` ; à déplacer vers `history.modern` (liste dans `to_move` de la fiche).
- [ ] Suite : fiches des 46 autres pages, puis générateur d'images des cartes, puis aperçu TestFlight (après le oui du propriétaire).
- [ ] Questions encore ouvertes : rareté liée à la difficulté de la notion (recommandé), échanges et bataille de cartes entre amis (plus tard ?), illustrations (cartes générées pour communes et rares, vraies illustrations pour épiques et légendaires).

**Arbre de Léon (maquette v7 à valider)**
- [x] Maquette validée (v3) : https://claude.ai/artifact/DqQPtHtPYLcPm2964daQHz — l'arbre part d'une graine et grandit (tronc + couronne ronde) avec le total des notions apprises ; étape écrite en haut (Graine → Pousse → Jeune plant → Arbuste → Jeune arbre → Grand arbre → Arbre centenaire) avec jauge ; un gros fruit par domaine, toujours à la même place, qui grossit avec les notions du domaine (emplacement en pointillés tant qu'il n'est pas commencé) ; étoiles dorées = rangs ; bourgeons gris = erreurs à corriger (bouton vers « Mes erreurs ») ; Léon de la couleur du domaine le plus fort.
- [x] Graines gardées (option A, maquette v4, même lien) : **taille de l'arbre = max(étape garantie par la culture, étape nourrie par les graines)**. Culture (notions apprises) : seuils 0 / 1 / 10 / 120 / 400 → garantit jusqu'à « Jeune arbre » au plus, donc jamais de fruits sans arbre. Graines données (« Nourrir 10 / 50 ») : seuils 0 / 50 / 150 / 300 / 500 / 800 / 1200 → seules elles mènent à « Grand arbre » (en fleurs) et « Arbre centenaire ». Les fruits viennent uniquement des bonnes réponses. Pas de jardin ni de décorations (essayé puis retiré) ; les accessoires de Léon restent dans leur écran actuel. Maquette v7 : l'arbre est tout en haut de l'écran, la carte de taille et le bouton « Nourrir » juste dessous.
- [ ] Arbre sur l'accueil (maquette à valider) : https://claude.ai/artifact/64jgcxCzjxDtJKMeN17TsG — accueil (onglet 5 du jour) dans l'ordre : date, série et sac · Léon · carte du 5 du jour · **arbre de la connaissance** · défis ; le bloc « Aujourd'hui » (erreurs à revoir, terrain à conquérir, ligue) est retiré (erreurs : « Jouer » et bourgeons de l'arbre ; ligue : « Amis »). Chaque fruit = un domaine : le toucher ouvre sa fiche (rang, notions, erreurs, « Jouer en classée », « Entraînement », « Corriger mes erreurs ») ; après le 5 du jour ou une partie, les fruits concernés grossissent et une bulle résume « +N notions : Histoire +1… » ; bouton « Mon arbre › » vers l'écran complet ; nouveau joueur : une graine, puis ses premiers fruits dès sa première partie. (Une première version sur l'écran « Jouer » n'a pas plu.)
- [ ] À coder (partie B, serveur + app) : fonction serveur « mon arbre » (notions apprises, rang et erreurs par domaine, à partir de user_concepts et des Elo par domaine, graines données) ; écran de l'arbre refait ; arrosoir à repenser (ex. dons comptés double). Plus de tenues de Léon (D-040).

**Après la publication**
- [ ] Lier l'app dans AdMob.
- [ ] DSA : infos de commerçant à revalider dans App Store Connect (mail d'Apple du 6 octobre), sinon l'app n'est pas disponible dans l'UE.

## Commandes utiles
`scripts/test-db.sh` · `scripts/gen-fixtures.sh` (après test-db) · `node scripts/build-seed.mjs` · `python3 scripts/make-icon.py <sortie>` · `node scripts/icons/render.mjs` (icônes 3D : coffres, graines, flamme, joker, tickets, arrosoir → `Assets.xcassets/Icons`) · `cd ios && xcodegen`
