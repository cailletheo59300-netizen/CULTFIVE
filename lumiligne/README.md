# Lumiligne

Casse-tête de déduction pour iPhone : **une gemme par zone de couleur, les numéros qui se suivent sont alignés, et les gemmes ne se touchent jamais.** Quand la chaîne est complète, le rayon la parcourt de bout en bout.

- Jeu à part, sans lien avec Brainlix ni Écho. Seule la structure technique (pubs, achats, Game Center, workflows) a été reprise d'Écho, en copie adaptée.
- Sans serveur : tout est sur le téléphone. Les classements passent par Game Center, les achats par StoreKit 2 (vérifiés sur le téléphone).
- Aucune grille faite à la main : elles sont **générées par le code**. Le solveur garantit qu'il n'y a qu'une solution, qu'on la trouve **par déduction pure** (sans deviner), et il mesure la difficulté.
- Règles et réglages : [`docs/REGLES.md`](docs/REGLES.md).

## Organisation

| Dossier | Contenu |
|---|---|
| `Packages/LumiCore` | Toute la logique, sans interface, avec ses tests (`swift test`) : règles (`Layout`), solveur (`Solver`), générateur (`Generator`), partie en cours et indices (`Board`), niveaux et grille du jour (`Puzzles`), profil, économie, thèmes et achats (`Catalog`), rythme des pubs. |
| `Lumiligne/App` | Démarrage, modèle principal (`AppModel`), couleurs et polices (`Style`). |
| `Lumiligne/Game` | Écran de jeu (`GameView`), grille dessinée et gestes (`BoardView`), partie en cours (`GameSession`). |
| `Lumiligne/Screens` | Accueil, Boutique, Réglages et « Comment jouer ». |
| `Lumiligne/Services` | Pubs (`Ads.swift`), achats (`Store.swift`), Game Center, sons et vibrations (`Feedback.swift`). |
| `Lumiligne/Resources` | Icône, couleur de lancement, déclaration de confidentialité. |
| `project.yml` | Projet Xcode, généré par XcodeGen (le `.xcodeproj` n'est pas versionné). |

## Vérifier et construire
- **CI « Lumiligne CI »** (GitHub Actions, à chaque envoi qui touche `lumiligne/`) : tests de la logique, puis build de l'app.
- **Sur un Mac** : `brew install xcodegen && cd lumiligne && xcodegen`, puis ouvrir `Lumiligne.xcodeproj`. Les tests : `swift test --package-path lumiligne/Packages/LumiCore`.
- **TestFlight** : onglet Actions → « Lumiligne TestFlight » → Run workflow, en déclenchement manuel uniquement. Même clé App Store Connect que Brainlix (secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, déjà en place).

## Avant la première version TestFlight (à faire par le propriétaire)

### 1. Identifiant et app (minimum pour tester)
- Certificates, Identifiers & Profiles → Identifiers → « + » → App IDs → App : Bundle ID explicite `app.brainlix.lumiligne`, avec **Game Center** et **In-App Purchase** (rien d'autre).
- App Store Connect → Mes apps → « + » → Nouvelle app : iOS, nom « Lumiligne », langue français, identifiant `app.brainlix.lumiligne`, SKU `lumiligne`.

C'est tout pour TestFlight en interne. Le reste peut attendre.

### 2. Game Center : 2 classements (pour tester les classements)
App Store Connect → l'app → Services → Game Center → Classements :

| Classement | Identifiant (exact) | Type | Tri | Format |
|---|---|---|---|---|
| Niveau atteint | `app.brainlix.lumiligne.level` | Classique | Meilleur score, **décroissant** | Entier |
| Grille du jour | `app.brainlix.lumiligne.daily` | **Récurrent** : début 00:00 UTC, durée 1 jour, se répète chaque jour | **Croissant** (le plus petit temps gagne) | Entier, suffixe « s » (secondes) |

Le temps du jour compte +30 s par indice utilisé. Il faut aussi cocher Game Center dans la version de l'app au moment de l'envoyer à Apple.

### 3. Achats intégrés (pour tester la boutique)

| Identifiant | Type | Nom affiché | Prix conseillé |
|---|---|---|---|
| `app.brainlix.lumiligne.noads` | Non consommable | Sans pub | 3,99 € |
| `app.brainlix.lumiligne.starter` | Non consommable | Pack de départ (Sans pub + 30 indices + thèmes Néon et Aurore) | 4,99 € |
| `app.brainlix.lumiligne.theme.neon` | Non consommable | Thème Néon | 1,99 € |
| `app.brainlix.lumiligne.theme.aurora` | Non consommable | Thème Aurore | 1,99 € |
| `app.brainlix.lumiligne.hints.small` | Consommable | 10 indices | 0,99 € |
| `app.brainlix.lumiligne.hints.medium` | Consommable | 30 indices | 1,99 € |
| `app.brainlix.lumiligne.hints.large` | Consommable | 100 indices | 4,99 € |

Chaque achat a besoin d'une capture d'écran pour l'examen d'Apple (la boutique suffit). Les premiers achats partent à l'examen avec la première version.

### 4. AdMob (avant la sortie)
- AdMob → Applications → Ajouter une application → iOS → « Lumiligne » (« non publiée » pour l'instant).
- Créer 3 blocs : 2 récompensés (« Un indice », « Grille bonus ») et 1 interstitiel (« Entre les grilles »).
- Me donner les identifiants (ils sont publics) : je les mets dans `Config/App.xcconfig` (`ADMOB_APP_ID`) et `Lumiligne/Services/Ads.swift` (`AdConfig`).
- En attendant, l'app utilise les identifiants de test de Google. Xcode et TestFlight affichent toujours des pubs de test.
- `app-ads.txt` : rien à faire, celui de brainlix.site couvre déjà le compte. Indiquer `https://brainlix.site` comme site du développeur dans la fiche.

### 5. Fiche App Store (avant la sortie)
- URL d'assistance : `https://brainlix.site/lumiligne/support` ; confidentialité : `https://brainlix.site/lumiligne/confidentialite` (pages à créer sur le site, sur ton « go »).
- Confidentialité (« App Privacy ») : l'app ne collecte rien elle-même ; Google AdMob collecte des données : **Identifiants**, **Données d'utilisation**, **Diagnostic** ; usage : publicité tierce et analyse ; « utilisées pour le suivi » : oui, si le joueur accepte la demande d'Apple.
- Classification : jeu sans violence ni contenu sensible. Pubs limitées au niveau « PG » dans le code.

## Garder en tête
- La progression (niveaux, indices, série, thèmes débloqués, grilles commencées) est sur le téléphone. Les achats se restaurent avec « Restaurer les achats ».
- Changer le générateur, le solveur ou `Puzzles.swift` change les grilles des joueurs (grille du jour comprise) : à faire avant la sortie (voir `docs/REGLES.md`).
- Ne jamais renommer un champ de `Profile` : les sauvegardes des joueurs ne se liraient plus.
