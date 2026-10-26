import Foundation

/// Avatars des joueurs (D-115) : 8 grandes figures de la culture en bustes 3D, rangées dans `avatar.animal` côté serveur
/// (nom de clé d'origine, D-113). Une au hasard pour chacun, changeable gratuitement depuis le profil.
public enum AnimalAvatar: String, CaseIterable, Codable, Hashable, Sendable {
    case vinci, curie, newton, napoleon, mozart, cleopatra, shakespeare, socrates

    /// Personnage d'un avatar reçu du serveur (nil : ancien serveur, ou valeur inconnue).
    public init?(_ avatar: JSONValue?) {
        guard let raw = avatar?["animal"]?.stringValue, let value = AnimalAvatar(rawValue: raw) else { return nil }
        self = value
    }

    /// Personnage stable pour un joueur sans avatar (ancien serveur) : toujours le même pour un même pseudo.
    public static func fallback(for handle: String) -> AnimalAvatar {
        let sum = handle.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return allCases[sum % allCases.count]
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
        }
    }

    /// Nom de l'image dans le catalogue de l'app.
    public var imageName: String { "avatar_\(rawValue)" }
}
