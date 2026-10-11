# Générateur de cartes (brouillon)

`cartes-template.html` dessine les cartes : médaillon gravé selon le domaine, sujet au trait, bande du chiffre clé, nom, phrase, pied de carte, cadre selon la rareté (commune, rare, épique, légendaire), version brillante, inclinaison, et resserrement automatique des textes longs.

La carte est un empilement de couches (voir D-044) : 1 cadre (matière selon la rareté, remplaçable par un cadre cosmétique `skin-…`), 2 papier (selon la rareté), 3 illustration (fond, médaillon et reflet selon la rareté ; dessin au trait unique), 4 textes (écrits à l'affichage), 5 finition cosmétique (`fin-…`), 6 lumière (inclinaison). Ajouter un cadre ou une finition = ajouter une couche, sans toucher aux cartes.

Les dessins sont dans `sujets/` : une fonction par carte, rangée par page (`SUBJECTS['history.middle_ages'][1] = …`). Pages dessinées : Moyen Âge, Espace, Relief.

Planche : `python3 scripts/album/planche.py . history.middle_ages science.space geography.relief /tmp/planche.html`

Prochaines étapes : dessiner les sujets des autres pages, puis exporter des images pour l'app.
