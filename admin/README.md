# Admin Brainlix

Page web autonome (`index.html`, aucune dépendance) pour gérer le contenu sans passer par le code.

## Ce qu'on peut faire
- **Tableau de bord** : joueurs, 5 du jour terminés, réponses sur 7 jours, signalements ouverts, questions à revoir, et nombre de questions publiées **par thème** (en orange sous 20).
- **Questions** : filtrer (domaine, thème, statut, type, « à revoir », recherche) et trier (plus récentes, plus difficiles, plus faciles, taux de réussite le plus bas, plus jouées, plus signalées). Un clic ouvre l'éditeur.
- **Éditeur** : énoncé, bonne réponse (éditeur adapté au type : options à cocher, vrai/faux, nombre + tolérance, classement, associations), explication, « À retenir », indice, source, fourchette de difficulté ; Publier / Désactiver ; historique des signalements et clôture.
- **Signalements** : les questions signalées par les joueurs (bouton « Signaler » sous chaque explication dans l'app), les plus signalées d'abord.
- **5 du jour** : voir la série d'une date, la générer, remplacer une question (confirmation demandée si des joueurs ont déjà commencé).
- **Nouvelle question** : créée en brouillon, publiée depuis l'éditeur.

## Mise en route (le jour où le projet Supabase existe)
1. Ouvrir `admin/index.html` dans un navigateur (double-clic suffit), ou le déposer sur un hébergement statique privé.
2. Saisir l'URL du projet et la clé **anon** (Project Settings → API). Elles restent dans le navigateur.
3. Se créer un compte, puis se déclarer admin en SQL :
   `insert into public.app_admins (user_id) select id from auth.users where email = 'ton@email.fr';`
4. Se connecter avec le code reçu par e-mail.

Sécurité : toutes les actions passent par les fonctions `admin_*`, qui refusent tout compte absent de `app_admins`. Seule la clé anon (publique par nature) est utilisée.

Testé contre la base de test locale via un faux serveur REST (connexion, liste, tri, édition, création → publication, génération du 5 du jour).
