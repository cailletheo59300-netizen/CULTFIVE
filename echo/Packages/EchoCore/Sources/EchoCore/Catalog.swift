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

    /// Façon de dessiner une traînée.
    public enum Style: String, Sendable {
        /// Une seule couleur.
        case solid
        /// Les couleurs défilent le long de la traînée.
        case gradient
        /// Toutes les couleurs de l'arc-en-ciel, qui tournent.
        case rainbow
        /// Couleurs qui scintillent (feu, galaxie).
        case flicker
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
        Skin(id: "trail.gold", kind: .trail, name: "Or", price: .coins(500), colors: ["#FFE07A", "#FFB23D"], style: .gradient),
        Skin(id: "trail.ice", kind: .trail, name: "Glace", price: .coins(700), colors: ["#FFFFFF", "#9ADFFF", "#5AA8FF"], style: .gradient),
        Skin(id: "trail.rainbow", kind: .trail, name: "Arc-en-ciel", price: .coins(1200), colors: ["#FFFFFF"], style: .rainbow),
        Skin(id: "trail.fire", kind: .trail, name: "Feu", price: .store(.trailFire),
             colors: ["#FFF3B0", "#FFC93D", "#FF7A1A", "#FF3D2E"], style: .flicker),
        Skin(id: "trail.galaxy", kind: .trail, name: "Galaxie", price: .store(.trailGalaxy),
             colors: ["#FFFFFF", "#B98CFF", "#6B5CFF", "#FF6BD6"], style: .flicker),
    ]

    public static let decors: [Skin] = [
        Skin(id: "decor.night", kind: .decor, name: "Nuit", price: .free,
             colors: ["#0B1026", "#05060F", "#FF4D9A", "#FFD84D", "#2A3466"]),
        Skin(id: "decor.ocean", kind: .decor, name: "Océan", price: .coins(400),
             colors: ["#04283A", "#020E1A", "#FF8F6B", "#7CFFE4", "#145A73"]),
        Skin(id: "decor.forest", kind: .decor, name: "Forêt", price: .coins(600),
             colors: ["#0C2418", "#040D08", "#FF6B6B", "#E8FF7A", "#1F4D33"]),
        Skin(id: "decor.ink", kind: .decor, name: "Encre", price: .coins(900),
             colors: ["#1A1A1A", "#000000", "#FFFFFF", "#FF3B3B", "#3A3A3A"]),
        Skin(id: "decor.synthwave", kind: .decor, name: "Synthwave", price: .store(.decorSynthwave),
             colors: ["#2B0B3F", "#0D0221", "#00F0FF", "#FF2E97", "#7B2CBF"]),
    ]

    public static var all: [Skin] { trails + decors }

    public static func skin(_ id: String) -> Skin? { all.first { $0.id == id } }

    public static func trail(_ id: String) -> Skin { trails.first { $0.id == id } ?? trails[0] }
    public static func decor(_ id: String) -> Skin { decors.first { $0.id == id } ?? decors[0] }
}
