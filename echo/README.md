# Écho

Jeu iPhone : **chaque manche que tu joues devient un fantôme qui rejoue tes gestes. Ne touche pas ton passé.**

- Sans serveur : tout est sur le téléphone. Les classements passent par Game Center, les achats par StoreKit 2 (vérifiés sur le téléphone).
- Pubs AdMob (même compte que Brainlix) : récompensées (Continuer, Pièces ×2, Réessayer le défi) et entre les parties (rythme doux).
- Règles et réglages : [`docs/REGLES.md`](docs/REGLES.md).

## Organisation

| Dossier | Contenu |
|---|---|
| `Packages/EchoCore` | Toute la logique, sans interface, avec ses tests (`swift test`) : moteur de jeu, fantômes, orbes, défi du jour, profil, boutique, rythme des pubs. |
| `Echo/App` | Démarrage, modèle principal (`AppModel`), thème. |
| `Echo/Game` | Écran de jeu : scène SpriteKit (`GameScene`), partie en cours (`GameSession`), score, pause, fin de partie (`GameView`). |
| `Echo/Screens` | Accueil, Boutique, Réglages. |
| `Echo/Services` | Pubs (`Ads.swift`), achats (`Store.swift`), Game Center, sons et vibrations (`Feedback.swift`). |
| `Echo/Resources` | Icône, couleur de lancement, déclaration de confidentialité. |
| `project.yml` | Projet Xcode, généré par XcodeGen (le `.xcodeproj` n'est pas versionné). |
| `../site/echo` | Pages Aide, Confidentialité, Conditions (site brainlix.site). |

La logique avance par pas fixes de 1/60 s, la même sur tous les iPhone : un fantôme rejoue exactement la manche, et le défi du jour est le même pour tout le monde.

## Vérifier et construire
- **CI « Écho CI »** (GitHub Actions, à chaque envoi qui touche `echo/`) : tests de la logique, puis build de l'app.
- **Sur un Mac** : `brew install xcodegen && cd echo && xcodegen`, puis ouvrir `Echo.xcodeproj`. Les tests de la logique se lancent avec `swift test --package-path echo/Packages/EchoCore`.
- **TestFlight** : onglet Actions → « Écho TestFlight » → Run workflow, en déclenchement manuel uniquement. Il utilise la même clé App Store Connect que Brainlix (secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, déjà en place).

## Avant la première version TestFlight (à faire par le propriétaire)

### 1. App Store Connect : créer l'app
Mes apps → « + » → Nouvelle app :
- Plateforme : iOS ;
- Nom : « Écho », ou un autre nom si « Écho » est pris. Le nom affiché sur l'iPhone se change dans `Config/App.xcconfig` (`APP_DISPLAY_NAME`) ;
- Langue principale : français ;
- Identifiant de paquet : `app.brainlix.echo`. S'il n'apparaît pas dans la liste, lancer une fois le workflow TestFlight : la signature automatique le crée. Sinon, le créer à la main dans Certificates, Identifiers & Profiles, avec la capacité Game Center ;
- SKU : `echo`.

### 2. Game Center : 2 classements
App Store Connect → l'app → onglet Services → Game Center → Classements :

| Classement | Identifiant (exact) | Type | Tri | Format |
|---|---|---|---|---|
| Meilleur score | `app.brainlix.echo.classic` | Classique | Meilleur score, décroissant | Entier |
| Défi du jour | `app.brainlix.echo.daily` | **Récurrent** : début 00:00 UTC, durée 1 jour, se répète chaque jour | Meilleur score, décroissant | Entier |

Il faut aussi cocher Game Center dans la version de l'app au moment de l'envoyer à Apple.

### 3. Achats intégrés
App Store Connect → l'app → Achats intégrés. Identifiants exacts :

| Identifiant | Type | Nom affiché | Prix conseillé |
|---|---|---|---|
| `app.brainlix.echo.noads` | Non consommable | Sans pub | 3,99 € |
| `app.brainlix.echo.starter` | Non consommable | Pack de départ | 4,99 € |
| `app.brainlix.echo.trail.fire` | Non consommable | Traînée Feu | 1,99 € |
| `app.brainlix.echo.trail.galaxy` | Non consommable | Traînée Galaxie | 1,99 € |
| `app.brainlix.echo.decor.synthwave` | Non consommable | Décor Synthwave | 1,99 € |
| `app.brainlix.echo.coins.small` | Consommable | 600 pièces | 0,99 € |
| `app.brainlix.echo.coins.medium` | Consommable | 2 000 pièces | 2,99 € |
| `app.brainlix.echo.coins.large` | Consommable | 8 000 pièces | 9,99 € |

Chaque achat a besoin d'une capture d'écran pour l'examen d'Apple (la boutique suffit). Les premiers achats partent à l'examen avec la première version de l'app.

### 4. AdMob
- AdMob → Applications → Ajouter une application → iOS. Tant que l'app n'est pas sur l'App Store, répondre « non » à « publiée ? », puis l'associer à l'App Store après la sortie.
- Créer 4 blocs d'annonces :
  - 3 récompensés : « Continuer », « Pièces x2 », « Défi : essai en plus » ;
  - 1 interstitiel : « Entre les parties ».
- ✅ Fait : app « Echo » créée dans AdMob, identifiant dans `Config/App.xcconfig` (`ADMOB_APP_ID`), 4 blocs dans `Echo/Services/Ads.swift` (`AdConfig`).
- `app-ads.txt` : rien à faire. Celui de brainlix.site couvre déjà ce compte AdMob. Il faut seulement indiquer `https://brainlix.site` comme site du développeur dans la fiche App Store d'Écho.
- Xcode et TestFlight affichent toujours les pubs de test de Google : les vraies pubs ne passent que dans la version de l'App Store.

### 5. Fiche App Store
- URL d'assistance : `https://brainlix.site/echo/support`.
- URL de confidentialité : `https://brainlix.site/echo/confidentialite`.
- Confidentialité (« App Privacy ») : l'app ne collecte rien elle-même ; Google AdMob collecte des données. À déclarer :
  - **Identifiants** (identifiant de l'appareil), **Données d'utilisation** (interactions avec les pubs) et **Diagnostic** ;
  - usage : publicité tierce et analyse ;
  - « utilisées pour le suivi » : oui, si le joueur accepte la demande d'Apple.
- Classification : jeu sans violence ni contenu sensible. Les pubs sont limitées au niveau « PG » dans le code (`maxAdContentRating`).

## Garder en tête
- La progression (pièces, apparences achetées en pièces, records) est enregistrée sur le téléphone. Les achats en euros se restaurent avec « Restaurer les achats ».
- Changer un chiffre de `Tuning.swift` change le défi du jour (voir `docs/REGLES.md`).
- Ne jamais renommer un champ de `Profile` : les sauvegardes des joueurs ne se liraient plus.
