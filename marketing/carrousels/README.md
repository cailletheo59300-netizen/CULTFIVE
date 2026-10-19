# Carrousels TikTok / Instagram

Format inspiré des carrousels « photo » : accroche façon mème, 3 questions (réponse sur l'image suivante), appel à télécharger.
Images 1080 × 1920, fonds « peinture ancienne » générés (aucun droit d'image).

- Contenu : `carrousels.json` (accroche, questions, bonne réponse, explication, % de joueurs qui ont trouvé).
- Un vrai tableau du domaine public en fond : ajouter `"bg": "chemin/image.jpg"` à une question.
- Générer : `NODE_PATH=$(npm root -g) node generer.js dossier-de-sortie`
