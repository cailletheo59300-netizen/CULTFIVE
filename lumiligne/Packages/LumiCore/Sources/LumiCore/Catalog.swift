import Foundation

/// Achats intégrés (identifiants à créer à l'identique dans App Store Connect, voir `lumiligne/README.md`).
/// Tout s'achète directement : rien de payant au hasard.
public enum StoreProduct: String, CaseIterable, Sendable {
    /// Plus aucune pub entre les grilles (non consommable). Les pubs récompensées restent au choix du joueur.
    case noAds = "app.brainlix.lumiligne.noads"
    /// Pack de départ : Sans pub + 30 indices + les 2 thèmes premium (non consommable).
    case starter = "app.brainlix.lumiligne.starter"
    /// Indices (consommables).
    case hintsSmall = "app.brainlix.lumiligne.hints.small"
    case hintsMedium = "app.brainlix.lumiligne.hints.medium"
    case hintsLarge = "app.brainlix.lumiligne.hints.large"
    /// Thèmes premium (non consommables).
    case themeNeon = "app.brainlix.lumiligne.theme.neon"
    case themeAurora = "app.brainlix.lumiligne.theme.aurora"

    public var isConsumable: Bool {
        switch self {
        case .hintsSmall, .hintsMedium, .hintsLarge: true
        default: false
        }
    }

    /// Indices donnés par l'achat. Pour le pack de départ, ils ne sont donnés qu'une fois (achat, pas restauration).
    public var hints: Int {
        switch self {
        case .hintsSmall: 10
        case .hintsMedium: 30
        case .hintsLarge: 100
        case .starter: 30
        default: 0
        }
    }

    /// Thèmes débloqués.
    public var themes: [String] {
        switch self {
        case .themeNeon: ["theme.neon"]
        case .themeAurora: ["theme.aurora"]
        case .starter: ["theme.neon", "theme.aurora"]
        default: []
        }
    }

    public var removesAds: Bool { self == .noAds || self == .starter }
}

/// Un thème : couleurs du fond, des zones, des gemmes et du rayon. Tout est dessiné par le code.
public struct ThemeSkin: Identifiable, Equatable, Sendable {
    public enum Price: Equatable, Sendable {
        case free
        /// Débloqué en finissant ce niveau.
        case level(Int)
        case store(StoreProduct)
    }

    public let id: String
    public let name: String
    public let price: Price
    /// Fond sombre (textes clairs) ou clair.
    public let dark: Bool
    /// Fond haut, fond bas, surface des cartes, texte, traits de la grille.
    public let background: [String]
    public let surface: String
    public let text: String
    public let line: String
    /// Rayon et lueur des gemmes.
    public let beam: String
    /// Couleurs des zones, dans l'ordre (9 au plus).
    public let zones: [String]

    public init(id: String, name: String, price: Price, dark: Bool, background: [String], surface: String, text: String,
                line: String, beam: String, zones: [String]) {
        self.id = id
        self.name = name
        self.price = price
        self.dark = dark
        self.background = background
        self.surface = surface
        self.text = text
        self.line = line
        self.beam = beam
        self.zones = zones
    }
}

/// Tous les thèmes. Un nouveau thème = une entrée ici (couleurs + prix).
/// Les couleurs des zones sont choisies pour rester distinctes en luminosité (daltonisme) ; les numéros et symboles
/// des zones complètent les couleurs.
public enum Catalog {
    public static let defaultTheme = "theme.dawn"

    public static let themes: [ThemeSkin] = [
        ThemeSkin(id: "theme.dawn", name: "Aube", price: .free, dark: false,
                  background: ["#F3F1FA", "#E6EAF5"], surface: "#FFFFFF", text: "#1F2333", line: "#2A2F45", beam: "#F5A623",
                  zones: ["#FFC2C2", "#FFE28A", "#B6E7AE", "#A6D6F2", "#D3C2F7", "#FFCB9C", "#9DE3D4", "#F6BCDD", "#D8D1C2"]),
        ThemeSkin(id: "theme.night", name: "Nuit", price: .free, dark: true,
                  background: ["#1A1E2E", "#0E111B"], surface: "#232838", text: "#EEF0F7", line: "#07080D", beam: "#FFC94D",
                  zones: ["#94505A", "#94803A", "#55834E", "#40728F", "#6C5CA0", "#9A653A", "#2F8476", "#924F7A", "#716B60"]),
        ThemeSkin(id: "theme.mint", name: "Menthe", price: .level(15), dark: false,
                  background: ["#EEF7F2", "#DDEFE6"], surface: "#FFFFFF", text: "#173126", line: "#1F3A2E", beam: "#FF7A59",
                  zones: ["#BFEBD3", "#F9E6A7", "#A9D8EE", "#F4C4C9", "#CFE89A", "#D9CBF2", "#8FD6C2", "#FFD2B0", "#C9D6CF"]),
        ThemeSkin(id: "theme.coral", name: "Corail", price: .level(40), dark: false,
                  background: ["#FFF3EE", "#FBE3DA"], surface: "#FFFFFF", text: "#3A1E1A", line: "#4A2620", beam: "#2D9CDB",
                  zones: ["#FFB4A2", "#FFD98E", "#A8DCC4", "#9CC9F0", "#E5B8F0", "#F7C873", "#B9E0A5", "#F5A9C0", "#D9C8BE"]),
        ThemeSkin(id: "theme.ocean", name: "Océan", price: .level(80), dark: true,
                  background: ["#0F2A3D", "#081722"], surface: "#14344A", text: "#E8F6FF", line: "#03101A", beam: "#7CFFE4",
                  zones: ["#1F6E8C", "#2E8A7A", "#3E5C9A", "#7A6AB0", "#2B7FA8", "#4F9A6A", "#8A5A8F", "#3A7A9A", "#5C6F7F"]),
        ThemeSkin(id: "theme.neon", name: "Néon", price: .store(.themeNeon), dark: true,
                  background: ["#14072B", "#07020F"], surface: "#1E0F3A", text: "#FFFFFF", line: "#000000", beam: "#00F0FF",
                  zones: ["#FF2E97", "#FFB800", "#39FF88", "#2E9BFF", "#B44DFF", "#FF6A3D", "#00E5C7", "#FF4DD8", "#8A8AA8"]),
        ThemeSkin(id: "theme.aurora", name: "Aurore", price: .store(.themeAurora), dark: true,
                  background: ["#0B1A2A", "#120A24"], surface: "#162638", text: "#F2FFF8", line: "#050A12", beam: "#B8FF6B",
                  zones: ["#2FBF8F", "#7A5CFF", "#3FA0E0", "#C060E0", "#36D1B0", "#5A7BFF", "#9AD64A", "#E06AB0", "#6C7F94"]),
    ]

    public static func theme(_ id: String) -> ThemeSkin { themes.first { $0.id == id } ?? themes[0] }
}
