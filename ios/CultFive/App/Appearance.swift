import SwiftUI

/// Apparence de l'app. Brainlix est pensée en clair : c'est le réglage par défaut, quel que soit celui de l'iPhone.
/// Le sombre (ou « comme l'iPhone ») est un choix volontaire, dans les Réglages.
enum AppAppearance: String, CaseIterable, Identifiable {
    case light, dark, system

    static let storageKey = "appearance"

    var id: String { rawValue }

    /// Schéma imposé à toute l'app (nil = celui du système).
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var title: String {
        switch self {
        case .light: return "Clair"
        case .dark: return "Sombre"
        case .system: return "Comme l'iPhone"
        }
    }
}

/// Préférences locales de jeu (propres à l'appareil).
enum GamePreferences {
    static let hapticsKey = "haptics"

    /// Vibrations activées (par défaut : oui).
    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
    }
}
