# Générateur de cartes (brouillon)

`cartes-template.html` dessine les cartes : médaillon gravé selon le domaine, sujet au trait, bande du chiffre clé, nom, phrase, pied de carte, cadre selon la rareté (commune, rare, épique, légendaire), version brillante, inclinaison, et resserrement automatique des textes longs.

Les dessins sont dans `sujets/` : une fonction par carte, rangée par page (`SUBJECTS['history.middle_ages'][1] = …`). Pages dessinées : Moyen Âge, Espace, Relief.

Planche : `python3 scripts/album/planche.py . history.middle_ages science.space geography.relief /tmp/planche.html`

Prochaines étapes : dessiner les sujets des autres pages, puis exporter des images pour l'app.
