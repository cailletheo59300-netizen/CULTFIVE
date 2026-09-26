import SwiftUI
import UIKit

// Tokens du design system. Toute couleur de l'app passe par ici (voir docs/DESIGN_SYSTEM.md).

extension Color {
    /// Fond d'écran : blanc très légèrement lavande (les cartes blanches s'en détachent).
    static let paper = Color(light: 0xF6F5FB, dark: 0x0E0D16)
    /// Surface des cartes.
    static let paperRaised = Color(light: 0xFFFFFF, dark: 0x1C1A2A)
    static let ink = Color(light: 0x1A1830, dark: 0xF4F3FA)
    static let inkSoft = Color(light: 0x6E6B85, dark: 0xA3A0B8)
    static let hairline = Color(light: 0xE9E7F2, dark: 0x2C2940)
    /// Couleur de marque : violet électrique. Boutons principaux, écrans de moment fort.
    static let brand = Color(light: 0x6A4CFF, dark: 0x8469FF)
    static let brandDeep = Color(hex: 0x3A1FB8)
    /// Accent « soleil » : score, surlignages sur fond violet. Toujours avec du texte foncé.
    static let sun = Color(hex: 0xFFD23F)
    static let correct = Color(light: 0x12B76A, dark: 0x3DDC97)
    static let wrong = Color(light: 0xFF4D5E, dark: 0xFF6B7A)
    /// Joues de Léon, confettis.
    static let blush = Color(hex: 0xFF8FB1)
    /// Encre fixe (ne s'inverse pas en mode sombre) : textes sur fond clair fixe, fonds de cartes de partage.
    static let inkFixed = Color(hex: 0x1A1830)
    static let paperFixed = Color(hex: 0xFFFFFF)

    /// Dégradé des moments forts (résultat, accueil, cartes de partage).
    static let popGradient = LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)

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

/// Couleurs de domaine : vives, une par domaine. Les grandes surfaces colorées portent un texte `onColor`.
enum DomainPalette {
    static func color(_ domainId: String) -> Color {
        Color(hex: hex(domainId))
    }

    /// Texte lisible sur l'aplat du domaine.
    static func onColor(_ domainId: String) -> Color {
        domainId == "music" ? .inkFixed : .white
    }

    static func hex(_ domainId: String) -> UInt32 {
        switch domainId {
        case "calc": return 0x2F6BFF
        case "french": return 0xF0588F
        case "geography": return 0x0CA678
        case "history": return 0xF76707
        case "science": return 0x1098AD
        case "logic": return 0x845EF7
        case "arts": return 0xD6336C
        case "sport": return 0xE5383B
        case "cinema": return 0x5F3DC4
        case "music": return 0xFCC419
        case "tech": return 0x1C7ED6
        case "nature": return 0x37B24D
        default: return 0x6E6B85
        }
    }

    /// Pictogramme SF Symbols du domaine (tuiles, cartes).
    static func symbol(_ domainId: String) -> String {
        switch domainId {
        case "calc": return "plus.forwardslash.minus"
        case "french": return "character.book.closed.fill"
        case "geography": return "globe.europe.africa.fill"
        case "history": return "building.columns.fill"
        case "science": return "atom"
        case "logic": return "puzzlepiece.fill"
        case "arts": return "paintpalette.fill"
        case "sport": return "figure.run"
        case "cinema": return "film.fill"
        case "music": return "music.note"
        case "tech": return "cpu.fill"
        case "nature": return "leaf.fill"
        default: return "sparkles"
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

/// Rayons : tout est arrondi, rien n'est carré.
enum Radius {
    static let s: CGFloat = 14
    static let m: CGFloat = 20
    static let l: CGFloat = 28
}

enum Motion {
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.6)
    static let standard = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let moment = Animation.spring(response: 0.55, dampingFraction: 0.68)
    /// Rebond franc (verdict, apparition d'un chiffre).
    static let bounce = Animation.spring(response: 0.4, dampingFraction: 0.5)

    /// Respecte « Réduire les animations » : fondu court à la place du mouvement.
    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : animation
    }
}
