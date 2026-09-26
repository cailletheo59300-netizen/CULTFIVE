import SwiftUI
import UIKit

// Tokens du design system. Toute couleur de l'app passe par ici (voir docs/DESIGN_SYSTEM.md).

extension Color {
    static let paper = Color(light: 0xF5F1E8, dark: 0x14120F)
    static let paperRaised = Color(light: 0xFFFDF8, dark: 0x1E1B17)
    static let ink = Color(light: 0x16140F, dark: 0xF2EDE3)
    static let inkSoft = Color(light: 0x5E574C, dark: 0xA39B8D)
    static let hairline = Color(light: 0xE3DCCD, dark: 0x2E2A24)
    /// Couleur de marque : uniquement sur fond encre, ou en aplat avec texte encre.
    static let chloro = Color(light: 0xC6F432, dark: 0xC6F432)
    static let correct = Color(light: 0x1E7A4C, dark: 0x5BC48A)
    static let wrong = Color(light: 0xB8382A, dark: 0xF07A6A)
    /// Encre fixe (ne s'inverse pas en mode sombre) : écrans « plein encre » comme le résultat.
    static let inkFixed = Color(hex: 0x16140F)
    static let paperFixed = Color(hex: 0xF5F1E8)

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Couleurs de domaine : aplats sobres. La couleur n'envahit l'écran qu'à l'intérieur d'un domaine.
enum DomainPalette {
    static func color(_ domainId: String) -> Color {
        switch domainId {
        case "calc": return Color(hex: 0x2F4BD8)
        case "french": return Color(hex: 0x8E2A43)
        case "geography": return Color(hex: 0xC8612F)
        case "history": return Color(hex: 0xB8872B)
        case "science": return Color(hex: 0x1F6F78)
        case "logic": return Color(hex: 0x4A4E57)
        case "arts": return Color(hex: 0xC0567E)
        case "sport": return Color(hex: 0x3B8B3F)
        case "cinema": return Color(hex: 0x5B3A6E)
        case "music": return Color(hex: 0x34357A)
        case "tech": return Color(hex: 0x3F6E9A)
        case "nature": return Color(hex: 0x6C7F2E)
        default: return .inkSoft
        }
    }

    /// Libellé court de secours si le référentiel n'est pas encore chargé.
    static func fallbackName(_ domainId: String) -> String {
        switch domainId {
        case "calc": return "Calcul"
        case "french": return "Français"
        case "geography": return "Géographie"
        case "history": return "Histoire"
        case "science": return "Sciences"
        case "logic": return "Logique"
        case "arts": return "Arts & culture"
        case "sport": return "Sport"
        case "cinema": return "Cinéma"
        case "music": return "Musique"
        case "tech": return "Technologie"
        case "nature": return "Nature & animaux"
        default: return domainId.capitalized
        }
    }
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 40
    static let xxl: CGFloat = 64
    /// Marge latérale des écrans.
    static let gutter: CGFloat = 20
}

enum Motion {
    static let press = Animation.easeOut(duration: 0.18)
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let moment = Animation.spring(response: 0.6, dampingFraction: 0.82)

    /// Respecte « Réduire les animations » : fondu court à la place du mouvement.
    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : animation
    }
}
