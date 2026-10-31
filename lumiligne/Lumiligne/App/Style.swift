import SwiftUI
import UIKit
import LumiCore

/// Couleurs de l'interface, tirées du thème choisi (`Catalog`). Clair et doux par défaut (Aube).
struct Palette {
    let skin: ThemeSkin

    init(_ skin: ThemeSkin) { self.skin = skin }

    var dark: Bool { skin.dark }
    var backgroundTop: Color { Color(hex: skin.background[0]) }
    var backgroundBottom: Color { Color(hex: skin.background[1]) }
    var background: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }
    var surface: Color { Color(hex: skin.surface) }
    var text: Color { Color(hex: skin.text) }
    var secondary: Color { text.opacity(0.62) }
    var line: Color { Color(hex: skin.line) }
    var beam: Color { Color(hex: skin.beam) }
    var stroke: Color { text.opacity(dark ? 0.16 : 0.12) }
    var card: Color { dark ? Color.white.opacity(0.07) : surface }
    var error: Color { Color(hex: dark ? "#FF6B6B" : "#D93A3A") }
    var success: Color { Color(hex: dark ? "#3FD19A" : "#1F9D6B") }

    func zone(_ index: Int) -> Color { Color(hex: skin.zones[index % skin.zones.count]) }

    /// Symbole de chaque zone (option daltonisme), en plus de la couleur et du numéro.
    static let symbols = ["circle.fill", "triangle.fill", "square.fill", "diamond.fill", "star.fill", "heart.fill",
                          "hexagon.fill", "moon.fill", "plus"]
    static func symbol(_ zone: Int) -> String { symbols[zone % symbols.count] }
}

/// Polices : titres en serif (New York), texte en SF Pro.
enum Fonts {
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight) }
    static func number(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
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
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

/// Bouton principal : plein (couleur du texte du thème) ou discret.
struct PillButtonStyle: ButtonStyle {
    let palette: Palette
    var filled = true
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let color = tint ?? palette.text
        return configuration.label
            .font(Fonts.body(18, .bold))
            .foregroundStyle(filled ? (tint == nil ? palette.backgroundTop : Color.black.opacity(0.85)) : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(filled ? color : palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(filled ? .clear : palette.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Petite pastille (indices, série).
struct Chip: View {
    let palette: Palette
    let text: String
    let icon: String
    var iconColor: Color?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(iconColor ?? palette.beam)
            Text(text).font(Fonts.number(16)).foregroundStyle(palette.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(palette.card))
        .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
    }
}

/// Voile d'attente (pub ou achat en cours, grille en préparation).
struct LoadingVeil: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView().controlSize(.large).tint(.white)
        }
    }
}

/// Une gemme : losange facetté, avec son numéro.
struct GemView: View {
    let palette: Palette
    let color: Color
    let number: Int
    var size: CGFloat
    var lit = false
    var bad = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(LinearGradient(colors: [Color.white, color.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                    .stroke(bad ? palette.error : palette.line, lineWidth: max(2, size * 0.08)))
                .rotationEffect(.degrees(45))
                .frame(width: size * 0.62, height: size * 0.62)
                .shadow(color: lit ? palette.beam.opacity(0.9) : .clear, radius: size * 0.25)
            Text("\(number)")
                .font(Fonts.number(size * 0.34, .heavy))
                .foregroundStyle(bad ? palette.error : Color(hex: "#1F2333"))
        }
        .frame(width: size, height: size)
    }
}
