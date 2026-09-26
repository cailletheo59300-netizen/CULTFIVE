# Changelog

## 0.5.1 — petits domaines
- Musique, sport, technologie enrichis via Wikidata : familles d'instruments, origine et décennie des groupes, Coupes du monde (vainqueur, hôte), villes des JO d'été et d'hiver, inventeurs ↔ inventions (listes relues).
- 96 questions écrites à la main : nature (classes d'animaux, petits et cris, plantes), logique (suites, horloges, âges, syllogismes), informatique, règles du sport, musique classique.
- Banque : 3 143 questions (musique 207, sport 110, tech 81, nature 46, logique 30).

## 0.5.0 — design « Pop »
- Nouvelle identité : fond clair lavande, violet électrique + jaune soleil, couleur vive et pictogramme par domaine, SF Pro Rounded gras, tout arrondi (cartes, pilules), boutons « jouet » qui s'enfoncent, rebonds, secousse sur une erreur, confettis. Nouvelle icône.
- Léon redessiné (rond, grands yeux, joues roses) et animé : attrape la bonne réponse avec sa langue, grisaille sur une erreur, arc-en-ciel sur un sans-faute, queue qui s'enroule avec la série, salue à l'accueil avec une bulle.
- Écrans refaits : question (voile de couleur du domaine, pastilles, progression en pilules), résultat du Daily (dégradé violet, score qui monte, célébrations), accueil (grande carte du jour), Jouer (cartes de modes, tuiles de domaines), domaine, profil (radar de culture), onboarding (ronde de domaines), barre d'onglets flottante, amis, ligues (podium).
- Célébrations : trophée, erreur corrigée, niveau passé (Daily et parties).
- Partage : modèles Violet / Soleil / Blanc ; nouvelles cartes « radar de culture » et « question du jour » (sans la réponse, depuis la revue).

## 0.4.0
- Nouveaux formats de géographie : localiser une capitale sur la carte, monnaie, langue officielle, site UNESCO → pays, silhouette du pays (nouvel affichage dans l'app).
- Anti-répétition : familles de questions (migration 0010), variantes de formulation. Banque : 2 716 questions.

## 0.3.1
- Daily : le créneau « Surprise » tire d'abord un domaine au hasard (migration 0009, testé sur 60 jours).
- Explications Wikidata enrichies (contexte des batailles, présentation des auteurs, pays et population pour les capitales).
- +80 questions écrites à la main (Calcul 40, Français 40), types variés. Banque : 1 958.

## 0.3.0 — session 2 (suite)
- Générateur Wikidata (CC0) : 1 613 questions (géographie, histoire, sciences, arts, cinéma), cache versionné, règles de français, garde-fous, relecture par échantillons. Banque : 1 886 questions.
- `CLAUDE.md` : règles de travail (validation des étapes avant de coder, captures sur demande uniquement).

## 0.2.0 — session 2 (2026-09-26)
- Mode démo (Debug uniquement) sur réponses RPC réelles enregistrées ; build simulateur pour Appetize.io ; 16 captures automatiques (clair/sombre) dans `docs/screenshots`.
- Contenu : +120 questions (273), vague 2 riche en classements, associations, vrai/faux et calcul.
- Trait de cinq : une réponse ratée = trait court et estompé (plus de pointillés).
- Profil : les niveaux fiables (≥ 10 réponses) en tête de « Ce que tu sais ».

## 0.1.0 — session 1 (2026-09-26)
- Phase 0 : cahier des charges analysé, architecture, décisions, design system, schéma de données.
- Backend Supabase complet et testé : Daily autoritaire (série commune, temps serveur, percentile honnête, série + jokers, cas limites minuit/fuseau/expiration/double soumission), adaptatif (Rasch + bayésien), calibration bornée, erreurs par concept, ledger XP/graines, trophées, Jouer (packs, soumission idempotente, aides), amis, parrainage anti-abus, ligues, admin, RLS.
- Contenu : 153 questions curées sur 12 domaines, pipeline JSON → seed validé.
- Package `CultFiveCore` : modèles, évaluation, pavé numérique, client Supabase maison, file hors-ligne, tests + contrats JSON.
- App SwiftUI : design system (trait de cinq, Léon, New York), onboarding jouable, 5 du jour, résultat, revue, Jouer (5 modes, domaines, stats), amis, ligues, profil, réglages, suppression de compte, partage 9:16, notifications locales.
- CI GitHub : SQL (Postgres 16), `swift test`, build + tests iOS.
