import SwiftUI
import UIKit
import EchoCore

/// Couleurs et polices de l'interface. Les couleurs du jeu (traînée, fantômes, fond) viennent des apparences
/// (`Catalog`) : voir `GameTheme`.
enum Theme {
    static let accent = Color(hex: "#4DF0FF")
    static let ghost = Color(hex: "#FF4D9A")
    static let gold = Color(hex: "#FFD84D")
    static let text = Color.white
    static let secondary = Color.white.opacity(0.62)
    static let card = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.14)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

/// Couleurs résolues d'une partie : traînée équipée + décor équipé.
struct GameTheme {
    let trail: Skin
    let decor: Skin

    init(trail: Skin, decor: Skin) {
        self.trail = trail
        self.decor = decor
    }

    init(profile: Profile) {
        self.init(trail: Catalog.trail(profile.equippedTrail), decor: Catalog.decor(profile.equippedDecor))
    }

    var backgroundTop: Color { Color(hex: decor.colors[0]) }
    var backgroundBottom: Color { Color(hex: decor.colors[1]) }
    var ghostColor: UIColor { UIColor(hex: decor.colors[2]) }
    var orbColor: UIColor { UIColor(hex: decor.colors[3]) }
    var borderColor: UIColor { UIColor(hex: decor.colors[4]) }

    var background: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    /// Couleur du point du joueur.
    var playerColor: UIColor { UIColor(hex: trail.colors[0]) }

    /// Couleur du morceau de traînée `index` (0 = juste derrière le point, 1 = le bout), à l'instant `time` (secondes).
    func trailColor(at index: Double, time: Double) -> UIColor {
        let colors = trail.colors.map { UIColor(hex: $0) }
        switch trail.style {
        case .solid:
            return colors.last ?? .white
        case .gradient:
            return UIColor.interpolate(colors, at: index)
        case .rainbow:
            let hue = (index * 0.6 + time * 0.35).truncatingRemainder(dividingBy: 1)
            return UIColor(hue: hue, saturation: 0.75, brightness: 1, alpha: 1)
        case .flicker:
            let wobble = 0.5 + 0.5 * sin(time * 18 + index * 9)
            return UIColor.interpolate(colors, at: min(1, index * 0.8 + wobble * 0.25))
        }
    }
}

extension UIColor {
    /// « #RRGGBB ».
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    /// Couleur à la position `t` (0…1) d'un dégradé.
    static func interpolate(_ colors: [UIColor], at t: Double) -> UIColor {
        guard colors.count > 1 else { return colors.first ?? .white }
        let position = max(0, min(1, t)) * Double(colors.count - 1)
        let i = min(Int(position), colors.count - 2)
        let f = CGFloat(position - Double(i))
        var (r1, g1, b1, a1, r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0, 0, 0, 0, 0)
        colors[i].getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        colors[i + 1].getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * f, green: g1 + (g2 - g1) * f, blue: b1 + (b2 - b1) * f, alpha: a1 + (a2 - a1) * f)
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

/// Bouton principal : grand, arrondi, lumineux.
struct GlowButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(19, .bold))
            .foregroundStyle(filled ? Color.black : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(filled ? color : color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(filled ? 0 : 0.6), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(filled ? 0.55 : 0), radius: 16)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Petite pastille (pièces, série).
struct Chip: View {
    let icon: String
    let text: String
    var color: Color = Theme.gold

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(Theme.body(16, .bold)).monospacedDigit().foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
    }
}
