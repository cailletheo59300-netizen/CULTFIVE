# Changelog

## 0.1.0 — session 1 (2026-09-26)
- Phase 0 : cahier des charges analysé, architecture, décisions, design system, schéma de données.
- Backend Supabase complet et testé : Daily autoritaire (série commune, temps serveur, percentile honnête, série + jokers, cas limites minuit/fuseau/expiration/double soumission), adaptatif (Rasch + bayésien), calibration bornée, erreurs par concept, ledger XP/graines, trophées, Jouer (packs, soumission idempotente, aides), amis, parrainage anti-abus, ligues, admin, RLS.
- Contenu : 153 questions curées sur 12 domaines, pipeline JSON → seed validé.
- Package `CultFiveCore` : modèles, évaluation, pavé numérique, client Supabase maison, file hors-ligne, tests + contrats JSON.
- App SwiftUI : design system (trait de cinq, Léon, New York), onboarding jouable, 5 du jour, résultat, revue, Jouer (5 modes, domaines, stats), amis, ligues, profil, réglages, suppression de compte, partage 9:16, notifications locales.
- CI GitHub : SQL (Postgres 16), `swift test`, build + tests iOS.
