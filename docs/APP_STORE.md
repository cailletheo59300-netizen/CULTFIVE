# Fiche App Store Connect — Brainlix

Réponses prêtes à recopier dans App Store Connect. À tenir à jour si l'app change (pubs, données, fonctions sociales).

## 1. Confidentialité de l'app (« App Privacy »)

**Collectez-vous des données ?** Oui.
**Suivi (tracking) ?** Oui : Google AdMob utilise l'identifiant publicitaire **seulement si le joueur majeur accepte** la demande d'Apple.

| Catégorie Apple | Type | Lié à l'utilisateur | Utilisé pour le suivi | Finalités |
|---|---|---|---|---|
| Coordonnées | Adresse e-mail | Oui | Non | Fonctionnalité de l'app |
| Contenu utilisateur | Contenu de jeu | Oui | Non | Fonctionnalité de l'app |
| Contenu utilisateur | Autre contenu (pseudo, nom de ligue, signalements) | Oui | Non | Fonctionnalité de l'app |
| Identifiants | Identifiant utilisateur | Oui | Non | Fonctionnalité de l'app |
| Identifiants | Identifiant de l'appareil (IDFA, via AdMob) | Oui | **Oui** | Publicité tierce, Fonctionnalité de l'app (anti-triche parrainage : empreinte brouillée) |
| Données d'utilisation | Interactions avec le produit | Oui | Non | Analyses, Fonctionnalité de l'app |
| Données d'utilisation | Données publicitaires (AdMob) | Non | **Oui** | Publicité tierce |
| Localisation | Localisation approximative (déduite de l'IP par AdMob) | Non | **Oui** | Publicité tierce |
| Diagnostics | Données de performance, autres données de diagnostic (AdMob) | Non | Non | Publicité tierce, Analyses |
| Autres données | Tranche d'âge | Oui | Non | Fonctionnalité de l'app, Publicité tierce (pubs adaptées à l'âge) |

Non collectés : nom, téléphone, adresse, santé, finances, contacts, photos, historique de navigation, localisation précise, données sensibles, achats.

**URL de la politique de confidentialité** : https://brainlix.site/confidentialite

## 2. Classification d'âge

Questionnaire (réponses) :
- Violence, horreur, contenu sexuel, nudité, grossièretés, drogues, alcool, tabac, jeux d'argent, armes : **Aucun**.
- Thèmes médicaux / matures : **Aucun** (questions de culture générale).
- Jeux de hasard simulés : **Non**. Coffres : récompenses aléatoires **gagnées en jouant**, jamais achetables (pas de « loot box » payante).
- Concours : **Non** (les ligues n'ont aucun prix de valeur réelle).
- Contenu généré par les utilisateurs : **Oui**, limité aux pseudos et noms de ligue (filtre de mots interdits, signalement, blocage, modération dans l'admin). Pas de messagerie ni de chat.
- Accès Web illimité : **Non**.
- Publicité : **Oui** (Google AdMob, contenu « adolescents » au plus pour les mineurs).

Âge retenu : **13+**. L'onboarding demande l'âge et bloque les moins de 13 ans.

## 3. Informations pour la revue Apple (« Notes »)

À coller dans « App Review Information → Notes » :

> Brainlix is a daily general-knowledge quiz (French). No login is required: an anonymous account is created on first launch; Sign in with Apple / email can be added later in Profile → Settings.
>
> - Age gate: the onboarding asks the user's age; under 13 cannot use the app.
> - Daily quiz: "5 du jour" tab. Ranked games: "Jouer" tab.
> - Social: Friends tab. Friends are added by username; a friend's profile has Duel, head-to-head stats, Report and Block (⋯ menu). Private leagues are created with the + button and joined with a code (each league has its own daily quiz).
> - User-generated content is limited to usernames and league names: blocked-words filter, Report (friend profile, league page, league members), Block, and moderation by our team.
> - Ads: Google AdMob. Rewarded ads are always optional (double seeds, chests, streak rescue, mistake correction); a rare interstitial may appear between ranked games after the first 3 days. Rewards are granted server-side after Google's server-side verification. Minors get non-personalized ads only and no ATT prompt.
> - Account deletion: Profile → Settings → "Supprimer mon compte". Data export: Profile → Settings → "Télécharger mes données".
>
> Contact: bonjour@brainlix.site

**Compte de démonstration** : non nécessaire (compte anonyme automatique).

## 4. Rappels

- **Chiffrement** : `ITSAppUsesNonExemptEncryption = NO` (déjà dans l'app).
- **Site de l'éditeur** sur la fiche App Store : https://brainlix.site (nécessaire pour que AdMob valide `app-ads.txt`).
- Après publication : relier l'app dans AdMob (Applications → Brainlix → « Associer à une plate-forme »), pour lever l'« Examen requis ».
