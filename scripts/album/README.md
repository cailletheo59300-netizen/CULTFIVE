# Générateur de cartes (brouillon)

`cartes-template.html` dessine les cartes : médaillon gravé selon le domaine, sujet au trait, bande du chiffre clé, nom, phrase, pied de carte, cadre selon la rareté (commune, rare, épique, légendaire), version brillante, inclinaison, et resserrement automatique des textes longs.

La carte est un empilement de couches (voir D-044) : 1 cadre (matière selon la rareté, remplaçable par un cadre cosmétique `skin-…`), 2 papier (selon la rareté), 3 illustration (fond, médaillon et reflet selon la rareté ; dessin au trait unique), 4 textes (écrits à l'affichage), 5 finition cosmétique (`fin-…`), 6 lumière (inclinaison). Ajouter un cadre ou une finition = ajouter une couche, sans toucher aux cartes.

Les dessins sont dans `sujets/` : une fonction par carte, rangée par page (`SUBJECTS['history.middle_ages'][1] = …`). Formes partagées (profil, laurier, livre ouvert, frise…) dans `sujets/subj_lib.js`. Pages dessinées : Histoire (4 pages), Sciences (5 pages), Géographie (5 pages). Drapeaux : `wavyFlag` dans `subj_geo.js`.

Planche : `python3 scripts/album/planche.py . history.antiquity history.middle_ages history.modern history.contemporary science.space geography.relief /tmp/planche.html`

Prochaines étapes : dessiner les sujets des autres pages, puis exporter des images pour l'app.

Contrôle des textes : `scripts/album/controle-textes.mjs` vérifie, avec les vraies polices, qu'aucun texte n'est coupé ni trop petit, qu'aucun chiffre ne touche l'image ou le texte et qu'aucun dessin ne touche l'en-tête, sur les 525 cartes (mode d'emploi en tête du fichier). Si une carte est signalée, raccourcir son unité ou sa phrase.

Les dessins restent dans la fenêtre d'image : s'ils dépassent en haut ou en bas, la planche les réduit autour du centre (`keepIn`). Le bouton « Médaillon rond » de la planche permet de comparer avec et sans médaillon.

Quand le dessin est déjà un rond (astre, pièce), la carte n'a pas de médaillon et le dessin est un peu agrandi : liste `NOMEDAL` dans `sujets/subj_lib.js`, à compléter pour les nouvelles pages.

Formes de pays et continents : toujours les vrais contours (Natural Earth, domaine public), générés par `cartes-geo.mjs` dans `sujets/subj_maps.js`, jamais dessinés à la main.
