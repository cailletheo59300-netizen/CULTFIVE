# Règles de travail — Lumiligne

Les règles du propriétaire de `/CLAUDE.md` (racine du dépôt) s'appliquent aussi ici : résumé court et accord avant de coder, réponses en français simple, pas de captures d'écran sans demande.

## Démarrer une session sur Lumiligne
Lire `lumiligne/README.md`, puis `lumiligne/docs/REGLES.md`. N'ouvrir ensuite que les fichiers utiles à la tâche.

## Repères
- Jeu à part : ne jamais toucher à Brainlix (`ios/`) ni à Écho (`echo/`). Pas de dépendance entre les jeux.
- Toute règle de jeu va dans `LumiCore`, avec un test. L'app (`Lumiligne/`) ne fait qu'afficher.
- Chiffres : indices et pubs dans `Economy.swift`, tailles et difficultés dans `Puzzles.swift`, thèmes et achats dans `Catalog.swift`.
- Le générateur doit rester déterministe : seulement `SeededRandom`, jamais `Int.random` ni l'ordre d'un `Set`/`Dictionary`.
- Ne jamais renommer un champ de `Profile` (sauvegardes des joueurs).
- Vérification : CI « Lumiligne CI » (tests + build). TestFlight : workflow « Lumiligne TestFlight », manuel, seulement sur le « go » du propriétaire.
