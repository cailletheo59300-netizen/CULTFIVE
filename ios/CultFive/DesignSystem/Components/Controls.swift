import SwiftUI
import UIKit
import CultFiveCore

// MARK: - Haptique

@MainActor
enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)

    static func selection() { selectionGenerator.selectionChanged() }
    static func success() { notificationGenerator.notificationOccurred(.success) }
    static func error() { notificationGenerator.notificationOccurred(.error) }
    static func soft() { softGenerator.impactOccurred(intensity: 0.7) }
}

// MARK: - Boutons

/// Action principale : aplat encre, texte + flèche. Pas de gros CTA arrondi générique.
struct InkButtonStyle: ButtonStyle {
    var fill: Color
    var text: Color
    var arrow: Bool

    init(fill: Color = .ink, text: Color = .paper, arrow: Bool = true) {
        self.fill = fill
        self.text = text
        self.arrow = arrow
    }

    func makeBody(configuration: Configuration) -> some View {
        InkButtonBody(configuration: configuration, fill: fill, text: text, arrow: arrow)
    }
}

private struct InkButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let text: Color
    let arrow: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: Space.s) {
            configuration.label
                .font(.system(.body).weight(.semibold))
            if arrow {
                Spacer(minLength: Space.s)
                Image(systemName: "arrow.right")
                    .font(.system(.body).weight(.semibold))
                    .offset(x: configuration.isPressed ? 3 : 0)
            }
        }
        .foregroundStyle(text)
        .padding(.horizontal, Space.l)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
        .animation(Motion.press, value: configuration.isPressed)
        .contentShape(Rectangle())
    }
}

/// Action secondaire : texte souligné.
struct TextLinkStyle: ButtonStyle {
    var color: Color = .ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout).weight(.medium))
            .underline(true, color: color.opacity(0.4))
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// Ligne éditoriale pressable (listes de domaines, réglages, modes de jeu).
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(Color.ink.opacity(configuration.isPressed ? 0.05 : 0))
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
    static var chloro: InkButtonStyle { InkButtonStyle(fill: .chloro, text: .inkFixed) }
    static var inverted: InkButtonStyle { InkButtonStyle(fill: .paperFixed, text: .inkFixed) }
}

extension ButtonStyle where Self == TextLinkStyle {
    static var textLink: TextLinkStyle { TextLinkStyle() }
}

extension ButtonStyle where Self == RowPressStyle {
    static var row: RowPressStyle { RowPressStyle() }
}

// MARK: - Éléments éditoriaux

struct Hairline: View {
    var color: Color = .hairline

    var body: some View {
        Rectangle().fill(color).frame(height: 1).accessibilityHidden(true)
    }
}

/// Pastille de domaine + libellé en capitales.
struct DomainTag: View {
    let domainId: String
    var name: String? = nil
    var onInk = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(DomainPalette.color(domainId)).frame(width: 8, height: 8)
            Text(name ?? DomainPalette.fallbackName(domainId))
                .labelCaps(onInk ? Color.paperFixed.opacity(0.7) : .inkSoft)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Niveau de connaissance : barre fine + zone d'incertitude hachurée claire.
struct SkillBar: View {
    let level: Int
    let reliability: Double
    var color: Color = .ink

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let position = width * CGFloat(min(max(level, 0), 100)) / 100
            let spread = width * CGFloat((1 - reliability) * 0.12)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.hairline).frame(height: 2)
                Capsule().fill(color.opacity(0.18))
                    .frame(width: max(spread * 2, 0), height: 6)
                    .offset(x: max(position - spread, 0))
                Capsule().fill(color).frame(width: max(position, 2), height: 2)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Niveau \(level) sur 100, fiabilité \(Reliability(reliability).label)")
    }
}

/// Encart de message bref (confirmation, erreur réseau).
struct Toast: View {
    let text: String
    var systemImage: String = "checkmark"

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(.callout).weight(.medium))
            .foregroundStyle(Color.paper)
            .padding(.horizontal, Space.m)
            .padding(.vertical, 12)
            .background(Color.ink, in: Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Montant de graines, avec l'icône de la monnaie.
struct SeedsAmount: View {
    let amount: Int
    var signed = false
    var color: Color = .ink

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill").imageScale(.small)
            Text(signed && amount > 0 ? "+\(amount)" : "\(amount)").monospacedDigit()
        }
        .foregroundStyle(color)
        .accessibilityElement()
        .accessibilityLabel("\(amount) \(amount > 1 ? Brand.currencyPlural : Brand.currencySingular)")
    }
}
