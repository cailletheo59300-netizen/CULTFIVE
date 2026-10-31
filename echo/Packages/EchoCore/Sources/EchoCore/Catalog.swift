import Foundation

/// Achats intégrés (identifiants à créer à l'identique dans App Store Connect, voir `echo/README.md`).
public enum StoreProduct: String, CaseIterable, Sendable {
    /// Plus aucune pub entre les parties (non consommable). Les pubs récompensées restent au choix du joueur.
    case noAds = "app.brainlix.echo.noads"
    /// Pack de départ : Sans pub + les 3 apparences premium (non consommable).
    case starter = "app.brainlix.echo.starter"
    /// Pièces (consommables).
    case coinsSmall = "app.brainlix.echo.coins.small"
    case coinsMedium = "app.brainlix.echo.coins.medium"
    case coinsLarge = "app.brainlix.echo.coins.large"
    /// Apparences premium (non consommables).
    case trailFire = "app.brainlix.echo.trail.fire"
    case trailGalaxy = "app.brainlix.echo.trail.galaxy"
    case decorSynthwave = "app.brainlix.echo.decor.synthwave"

    public var isConsumable: Bool { coins > 0 }

    /// Pièces données par un pack (0 pour les autres achats).
    public var coins: Int {
        switch self {
        case .coinsSmall: 600
        case .coinsMedium: 2000
        case .coinsLarge: 8000
        default: 0
        }
    }

    /// Apparences débloquées par cet achat.
    public var skins: [String] {
        switch self {
        case .trailFire: ["trail.fire"]
        case .trailGalaxy: ["trail.galaxy"]
        case .decorSynthwave: ["decor.synthwave"]
        case .starter: ["trail.fire", "trail.galaxy", "decor.synthwave"]
        default: []
        }
    }

    /// Cet achat retire les pubs entre les parties.
    public var removesAds: Bool { self == .noAds || self == .starter }
}

/// Une apparence : soit une traînée (le point du joueur), soit un décor (fond, fantômes, orbes).
public struct Skin: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable { case trail, decor }

    public enum Price: Equatable, Sendable {
        case free
        case coins(Int)
        case store(StoreProduct)
    }

    /// Façon de dessiner une apparence (effets dessinés par l'app, sans image).
    public enum Style: String, Sendable {
        // Traînées
        /// Une seule couleur.
        case solid
        /// Les couleurs défilent le long de la traînée.
        case gradient
        /// Toutes les couleurs de l'arc-en-ciel, qui tournent.
        case rainbow
        /// Couleurs qui scintillent.
        case flicker
        /// Flammes qui montent et braises (premium).
        case fire
        /// Poussière d'étoiles qui scintille (premium).
        case galaxy
        /// Ruban lumineux continu.
        case neon
        /// Longue queue qui s'étire.
        case comet
        /// Bulles qui flottent et éclatent.
        case bubbles
        /// Carrés rétro.
        case pixel
        /// Pétales qui tombent en tournant.
        case sakura
        /// Petits éclairs qui crépitent.
        case electric
        /// Gouttes qui refroidissent.
        case lava
        /// Gouttes d'acide qui coulent.
        case toxic
        // Décors
        case night, ocean, forest, ink, synthwave
    }

    public let id: String
    public let kind: Kind
    public let name: String
    public let price: Price
    /// Couleurs en hexadécimal (« #4DF0FF »).
    /// Traînée : [point, traînée…]. Décor : [fond haut, fond bas, fantômes, orbes, bord].
    public let colors: [String]
    public let style: Style

    public init(id: String, kind: Kind, name: String, price: Price, colors: [String], style: Style = .solid) {
        self.id = id
        self.kind = kind
        self.name = name
        self.price = price
        self.colors = colors
        self.style = style
    }
}

/// Toutes les apparences. Pour en ajouter une : une ligne ici (couleurs + prix), rien d'autre à dessiner.
public enum Catalog {
    public static let defaultTrail = "trail.classic"
    public static let defaultDecor = "decor.night"

    public static let trails: [Skin] = [
        Skin(id: "trail.classic", kind: .trail, name: "Écho", price: .free, colors: ["#4DF0FF", "#4DF0FF"]),
        Skin(id: "trail.mint", kind: .trail, name: "Menthe", price: .coins(200), colors: ["#7CFFB2", "#3DDC97"]),
        Skin(id: "trail.coral", kind: .trail, name: "Corail", price: .coins(300), colors: ["#FF8A7A", "#FF5E78"], style: .gradient),
        Skin(id: "trail.neon", kind: .trail, name: "Néon", price: .coins(400), colors: ["#FF3DF2", "#3DE8FF"], style: .neon),
        Skin(id: "trail.gold", kind: .trail, name: "Or", price: .coins(500), colors: ["#FFE07A", "#FFB23D"], style: .gradient),
        Skin(id: "trail.comet", kind: .trail, name: "Comète", price: .coins(600), colors: ["#FFFFFF", "#9FE7FF", "#4D7CFF"], style: .comet),
        Skin(id: "trail.ice", kind: .trail, name: "Glace", price: .coins(700), colors: ["#FFFFFF", "#9ADFFF", "#5AA8FF"], style: .gradient),
        Skin(id: "trail.bubbles", kind: .trail, name: "Bulles", price: .coins(800), colors: ["#E6FBFF", "#7FE3FF", "#3FA9F5"], style: .bubbles),
        Skin(id: "trail.pixel", kind: .trail, name: "Pixel", price: .coins(800),
             colors: ["#FF4D4D", "#FFD93D", "#4DFF88", "#4DA6FF", "#C04DFF"], style: .pixel),
        Skin(id: "trail.sakura", kind: .trail, name: "Sakura", price: .coins(1000), colors: ["#FFF0F6", "#FFB7D5", "#FF7AAE"], style: .sakura),
        Skin(id: "trail.rainbow", kind: .trail, name: "Arc-en-ciel", price: .coins(1200), colors: ["#FFFFFF"], style: .rainbow),
        Skin(id: "trail.electric", kind: .trail, name: "Électrique", price: .coins(1200),
             colors: ["#FFFFFF", "#B5F1FF", "#5AC8FF"], style: .electric),
        Skin(id: "trail.lava", kind: .trail, name: "Lave", price: .coins(1400),
             colors: ["#FFF1A8", "#FF9A1F", "#E8360E", "#5A1206"], style: .lava),
        Skin(id: "trail.toxic", kind: .trail, name: "Toxique", price: .coins(1500), colors: ["#F2FFB0", "#A8FF3D", "#2FA81A"], style: .toxic),
        Skin(id: "trail.fire", kind: .trail, name: "Feu", price: .store(.trailFire),
             colors: ["#FFF6C8", "#FFD23D", "#FF7A1A", "#E8230E"], style: .fire),
        Skin(id: "trail.galaxy", kind: .trail, name: "Galaxie", price: .store(.trailGalaxy),
             colors: ["#FFFFFF", "#C9A6FF", "#7B5CFF", "#FF6BD6"], style: .galaxy),
    ]

    public static let decors: [Skin] = [
        Skin(id: "decor.night", kind: .decor, name: "Nuit", price: .free,
             colors: ["#0B1030", "#03040C", "#FF4D9A", "#FFD84D", "#2A3466"], style: .night),
        Skin(id: "decor.ocean", kind: .decor, name: "Océan", price: .coins(400),
             colors: ["#0A4A6E", "#01101F", "#FF8F6B", "#7CFFE4", "#1D6F8C"], style: .ocean),
        Skin(id: "decor.forest", kind: .decor, name: "Forêt", price: .coins(600),
             colors: ["#123A26", "#030B06", "#FF6B6B", "#E8FF7A", "#2C6644"], style: .forest),
        Skin(id: "decor.ink", kind: .decor, name: "Encre", price: .coins(900),
             colors: ["#F6EEDC", "#E4D5BA", "#1C1A17", "#D7263D", "#B9A27E"], style: .ink),
        Skin(id: "decor.synthwave", kind: .decor, name: "Synthwave", price: .store(.decorSynthwave),
             colors: ["#2B0B4F", "#0D0221", "#00F0FF", "#FFE45C", "#FF2E97"], style: .synthwave),
    ]

    public static var all: [Skin] { trails + decors }

    public static func skin(_ id: String) -> Skin? { all.first { $0.id == id } }

    public static func trail(_ id: String) -> Skin { trails.first { $0.id == id } ?? trails[0] }
    public static func decor(_ id: String) -> Skin { decors.first { $0.id == id } ?? decors[0] }
}
