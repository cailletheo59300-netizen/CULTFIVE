# Changelog

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
