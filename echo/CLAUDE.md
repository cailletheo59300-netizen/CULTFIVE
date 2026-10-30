# Règles de travail — Écho

Les règles du propriétaire de `/CLAUDE.md` (racine du dépôt) s'appliquent aussi ici : résumé court et accord avant de coder, réponses en français simple, pas de captures d'écran sans demande.

## Démarrer une session sur Écho
Lire `echo/README.md`, puis `echo/docs/REGLES.md`. N'ouvrir ensuite que les fichiers utiles à la tâche.

## Repères
- Tous les chiffres du jeu : `Packages/EchoCore/Sources/EchoCore/Tuning.swift`. Prix et apparences : `Catalog.swift`. Rythme des pubs : `AdPacing.swift`.
- Toute nouvelle règle de jeu va dans `EchoCore`, avec un test. L'app (`Echo/`) ne fait qu'afficher.
- Ne jamais renommer un champ de `Profile` (sauvegardes des joueurs).
- Vérification : CI « Écho CI » (tests + build). TestFlight : workflow « Écho TestFlight », manuel, seulement sur le « go » du propriétaire.
