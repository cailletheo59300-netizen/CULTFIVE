# Admin Brainlix

Page web autonome, sans dépendance, publiée avec le site : **brainlix.site/admin** (source : `site/admin.html`, non indexée).

## Ce qu'on peut faire
- **Statistiques** : joueurs, actifs par jour / 7 j / 30 j, nouveaux joueurs, 5 du jour et parties par jour (graphiques), rétention J1 / J7 / J30, parcours des nouveaux joueurs, graines gagnées et dépensées, coffres ouverts, domaines joués, versions de l'app, événements.
- **Joueurs** : recherche par pseudo, tri (récents, actifs, réponses, série) ; fiche complète (Elo par domaine, parties, 5 du jour, graines, journal de l'app) ; renommer un pseudo, bannir (le joueur ne peut plus jouer et quitte ses ligues), débannir.
- **Tableau de bord** : joueurs, 5 du jour terminés, réponses sur 7 jours, signalements ouverts, questions à revoir, et nombre de questions publiées **par thème** (en orange sous 20).
- **Questions** : filtrer (domaine, thème, statut, type, « à revoir », recherche) et trier (plus récentes, plus difficiles, plus faciles, taux de réussite le plus bas, plus jouées, plus signalées). Un clic ouvre l'éditeur.
- **Éditeur** : énoncé, bonne réponse (éditeur adapté au type : options à cocher, vrai/faux, nombre + tolérance, classement, associations), explication, « À retenir », indice, source, fourchette de difficulté ; Publier / Désactiver ; historique des signalements et clôture.
- **Signalements** : les questions signalées par les joueurs (bouton « Signaler » sous chaque explication dans l'app), les plus signalées d'abord.
- **5 du jour** : voir la série d'une date, la générer, remplacer une question (confirmation demandée si des joueurs ont déjà commencé).
- **Nouvelle question** : créée en brouillon, publiée depuis l'éditeur.

## Mise en route
1. Ouvrir brainlix.site/admin (le projet de production est préréglé).
2. Saisir son e-mail et recevoir un code : le compte est créé au premier passage.
3. Se déclarer admin en SQL (une seule fois) :
   `insert into public.app_admins (user_id) select id from auth.users where email = 'ton@email.fr';`
4. Recharger la page.

Sécurité : toutes les actions passent par les fonctions `admin_*`, qui refusent tout compte absent de `app_admins`. Seule la clé anon (publique par nature) est utilisée.

Testé contre la base de test locale via un faux serveur REST (connexion, liste, tri, édition, création → publication, génération du 5 du jour).
