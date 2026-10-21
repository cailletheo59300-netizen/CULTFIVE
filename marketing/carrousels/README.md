# Carrousels TikTok / Instagram

Format inspiré des carrousels « photo » : accroche façon mème, 3 questions (réponse sur l'image suivante), appel à télécharger.
Images 1080 × 1920, fonds « peinture ancienne » générés (aucun droit d'image).

- Contenu : `carrousels.json` (accroche, questions, bonne réponse, explication, % de joueurs qui ont trouvé).
- Un vrai tableau du domaine public en fond : ajouter `"bg": "chemin/image.jpg"` à une question.
- Générer : `NODE_PATH=$(npm root -g) node generer.js dossier-de-sortie`
- Style de la 1re image : `ACCROCHE=elegant` (par défaut, italique Playfair et ornement doré) ou `ACCROCHE=tiktok` (Montserrat, gros texte blanc).
- Polices (licence libre SIL OFL, Google Fonts) dans `polices/` : Playfair Display, EB Garamond, Montserrat.

## Compte 2 : carrousels « faits »
Un fait par image (titre + explication, `**gras**` en doré), puis l'appli conseillée à la fin. Contenu : `faits.json`.
Générer (avec la photo de profil 1080 × 1080) : `FICHIER=faits.json NODE_PATH=$(npm root -g) node generer.js dossier`
À la publication sur TikTok : activer « Divulgation du contenu → Votre marque ».
