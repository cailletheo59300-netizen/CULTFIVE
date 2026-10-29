import Foundation

/// Avatars des joueurs (D-115) : 8 grandes figures de la culture en bustes 3D, rangées dans `avatar.animal` côté serveur
/// (nom de clé d'origine, D-113). Une au hasard pour chacun, changeable gratuitement depuis le profil.
public enum AnimalAvatar: String, CaseIterable, Codable, Hashable, Sendable {
    case vinci, curie, newton, napoleon, mozart, cleopatra, shakespeare, socrates
    /// Premium (D-120) : à la boutique.
    case joan, hugo, galileo, darwin
    /// Exclusifs : offre de bienvenue (Hypatie), Pack Prestige (Toutânkhamon, Athéna).
    case hypatia, tut, athena

    /// Les 8 personnages gratuits pour tous.
    public static let free: [AnimalAvatar] = [.vinci, .curie, .newton, .napoleon, .mozart, .cleopatra, .shakespeare, .socrates]
    public static let premium: [AnimalAvatar] = [.joan, .hugo, .galileo, .darwin]
    public static let exclusive: [AnimalAvatar] = [.hypatia, .tut, .athena]

    public var isFree: Bool { Self.free.contains(self) }

    /// Personnage d'un avatar reçu du serveur (nil : ancien serveur, ou valeur inconnue).
    public init?(_ avatar: JSONValue?) {
        guard let raw = avatar?["animal"]?.stringValue, let value = AnimalAvatar(rawValue: raw) else { return nil }
        self = value
    }

    /// Personnage stable pour un joueur sans avatar (ancien serveur) : toujours le même pour un même pseudo.
    public static func fallback(for handle: String) -> AnimalAvatar {
        let sum = handle.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return free[sum % free.count]
    }

    public var name: String {
        switch self {
        case .vinci: return "Léonard de Vinci"
        case .curie: return "Marie Curie"
        case .newton: return "Isaac Newton"
        case .napoleon: return "Napoléon"
        case .mozart: return "Mozart"
        case .cleopatra: return "Cléopâtre"
        case .shakespeare: return "Shakespeare"
        case .socrates: return "Socrate"
        case .joan: return "Jeanne d'Arc"
        case .hugo: return "Victor Hugo"
        case .galileo: return "Galilée"
        case .darwin: return "Charles Darwin"
        case .hypatia: return "Hypatie"
        case .tut: return "Toutânkhamon"
        case .athena: return "Athéna"
        }
    }

    /// Nom de l'image dans le catalogue de l'app.
    public var imageName: String { "avatar_\(rawValue)" }
}

/// Contour d'avatar acheté (D-120), rangé dans `avatar.ring`.
public enum AvatarRing: String, CaseIterable, Codable, Hashable, Sendable {
    case neon, gold, rainbow
    /// Exclusifs : Pack Prestige, offre de bienvenue.
    case prestige, welcome

    public static let forSale: [AvatarRing] = [.neon, .gold, .rainbow]

    public init?(_ avatar: JSONValue?) {
        guard let raw = avatar?["ring"]?.stringValue, let value = AvatarRing(rawValue: raw) else { return nil }
        self = value
    }

    public var name: String {
        switch self {
        case .neon: return "Néon"
        case .gold: return "Or"
        case .rainbow: return "Arc-en-ciel"
        case .prestige: return "Prestige"
        case .welcome: return "Bienvenue"
        }
    }
}

/// Titre sous le pseudo (D-120), rangé dans `avatar.title`.
public enum PlayerTitle: String, CaseIterable, Codable, Hashable, Sendable {
    case erudit, encyclo, genie
    /// Exclusif au Pack Prestige.
    case legend

    public static let forSale: [PlayerTitle] = [.erudit, .encyclo, .genie]

    public init?(_ avatar: JSONValue?) {
        guard let raw = avatar?["title"]?.stringValue, let value = PlayerTitle(rawValue: raw) else { return nil }
        self = value
    }

    public var text: String {
        switch self {
        case .erudit: return "Érudit"
        case .encyclo: return "Encyclopédie vivante"
        case .genie: return "Génie"
        case .legend: return "Légende"
        }
    }
}
