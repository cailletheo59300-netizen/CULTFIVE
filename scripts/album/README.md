# Générateur de cartes (brouillon)

`cartes-template.html` dessine les cartes d'une page de l'album : médaillon gravé, sujet au trait (une fonction de dessin par carte), bande du chiffre clé, nom, phrase, pied de carte, cadre selon la rareté (commune, rare, épique, légendaire), version brillante et inclinaison.

Pour l'instant seule la page Moyen Âge est dessinée (fonctions `SUBJECTS` 1 à 18). On remplace `/*DATA*/` par la liste `[n, nom, chiffre, précision, phrase]` des cartes de `content/album/history.middle_ages.json` pour obtenir la planche.

Prochaines étapes : valider le style avec le propriétaire, dessiner les sujets des 48 autres pages, puis exporter des images pour l'app.
