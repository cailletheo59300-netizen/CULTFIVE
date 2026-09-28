# Brainlix — Produit

> Source de vérité produit condensée. Le cahier des charges complet a été fourni par le propriétaire en session 1 ; ce fichier en garde l'essentiel et les arbitrages.

## En une phrase
Une app iOS native de culture générale : on joue, on apprend de chaque réponse, on voit son niveau réel évoluer par domaine, on revient chaque jour pour « le 5 du jour », et on se mesure à ses amis.

## Piliers
1. **Le 5 du jour (Daily)** — rituel quotidien, 5 questions variées (~5 min), une seule tentative officielle, score = bonnes réponses, départage au temps. Même série pour tout le monde un jour donné (condition d'un percentile honnête).
2. **Jouer** — partie rapide, entraînement par domaine/sous-domaine, mix surprise, mes erreurs, défi. Adaptatif. Rejouable à volonté.
3. **Progression** — niveau de connaissance par domaine et sous-domaine (0–100, adaptatif, avec confiance statistique) ≠ XP (activité).
4. **Social** — amis, lien d'invitation (parrainage), ligues privées hebdo/mensuelles, cartes de partage 9:16.

## Vocabulaire produit (figé)
| Terme | Définition |
|---|---|
| **5 du jour** | Le Daily. Onglet central. |
| **Niveau** (d'un domaine) | Estimation de compétence 0–100. Jamais confondu avec l'XP. |
| **Fiabilité** | Confiance statistique de l'estimation (affichée discrètement). |
| **XP / niveau d'XP** | Activité et régularité. |
| **Graines** | L'unique monnaie virtuelle. Cohérente avec « Cultive ce que tu sais ». |
| **Série** | Streak du 5 du jour. |
| **Joker de série** | Protecteur de série, max 2 en stock. |
| **Léon** | La mascotte : un caméléon tout rond, animé. Il prend la couleur du domaine, attrape les bonnes réponses avec sa langue, grisaille sur une erreur, passe à l'arc-en-ciel sur un sans-faute ; sa queue s'enroule avec la série. Jamais pendant qu'on répond. |
| **Ligue** | Classement privé entre amis sur une période (semaine / mois). |

## Domaines initiaux
Calcul · Français · Géographie · Histoire · Sciences · Logique · Arts & culture · Sport · Cinéma · Musique · Technologie · Nature & animaux.
Le Daily puise dans 4 « piliers » (Calcul, Français, Géographie, Histoire) + 1 Surprise (tous les autres).

## Arbitrages produit pris (voir DECISIONS.md pour le détail)
- Aucune aide payante (graines) dans le 5 du jour officiel : le classement reste équitable. Les aides existent en mode Jouer uniquement.
- Le Daily n'est pas adaptatif individuellement (même série pour tous) ; il est équilibré en difficulté. L'adaptatif s'exprime dans Jouer, Erreurs et Défi.
- Percentile : réel au-delà de 100 participants du jour, sinon **estimation de référence** explicitement étiquetée comme telle.
- Pas de leaderboard mondial en V1.
- Notifications : locales (programmées sur l'appareil), annulées quand le Daily est fait. Push social plus tard.
- Découverte avant inscription : compte anonyme Supabase, puis liaison Apple / e-mail sans perte de données.

## Hors V1 (architecture prête)
Leaderboard mondial, Daily+ Premium (classement séparé), stats avancées, IA conversationnelle, avatars 3D, marketplace.
