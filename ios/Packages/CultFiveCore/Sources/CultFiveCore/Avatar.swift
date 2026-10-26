import Foundation

/// Avatars des joueurs (D-113) : 8 animaux en 3D, rangés dans `avatar.animal` côté serveur. Un au hasard pour chacun,
/// changeable gratuitement depuis le profil.
public enum AnimalAvatar: String, CaseIterable, Codable, Hashable, Sendable {
    case fox, panda, cat, owl, frog, rabbit, bear, penguin

    /// Animal d'un avatar reçu du serveur (nil : ancien serveur, ou valeur inconnue).
    public init?(_ avatar: JSONValue?) {
        guard let raw = avatar?["animal"]?.stringValue, let value = AnimalAvatar(rawValue: raw) else { return nil }
        self = value
    }

    /// Animal stable pour un joueur sans avatar (ancien serveur) : toujours le même pour un même pseudo.
    public static func fallback(for handle: String) -> AnimalAvatar {
        let sum = handle.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return allCases[sum % allCases.count]
    }

    public var name: String {
        switch self {
        case .fox: return "Renard"
        case .panda: return "Panda"
        case .cat: return "Chat"
        case .owl: return "Hibou"
        case .frog: return "Grenouille"
        case .rabbit: return "Lapin"
        case .bear: return "Ours"
        case .penguin: return "Pingouin"
        }
    }

    /// Nom de l'image dans le catalogue de l'app.
    public var imageName: String { "avatar_\(rawValue)" }
}
