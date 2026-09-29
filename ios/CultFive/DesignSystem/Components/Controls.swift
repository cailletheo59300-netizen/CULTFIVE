import SwiftUI
import UIKit
import CultFiveCore

// MARK: - Haptique

@MainActor
enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)

    // Toutes les vibrations passent par ici : le réglage « Vibrations » les coupe d'un coup.
    static func selection() { if GamePreferences.hapticsEnabled { selectionGenerator.selectionChanged() } }
    static func success() { if GamePreferences.hapticsEnabled { notificationGenerator.notificationOccurred(.success) } }
    static func error() { if GamePreferences.hapticsEnabled { notificationGenerator.notificationOccurred(.error) } }
    static func soft() { if GamePreferences.hapticsEnabled { softGenerator.impactOccurred(intensity: 0.7) } }
}

// MARK: - Boutons

/// Action principale : pilule pleine, texte gras centré, ombre colorée, rebond au toucher.
struct InkButtonStyle: ButtonStyle {
    var fill: Color
    var text: Color
    var arrow: Bool

    init(fill: Color = .brand, text: Color = .white, arrow: Bool = false) {
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
                .font(.system(.body, design: .rounded).weight(.heavy))
            if arrow {
                Image(systemName: "arrow.right")
                    .font(.system(.body, design: .rounded).weight(.heavy))
                    .offset(x: configuration.isPressed ? 3 : 0)
            }
        }
        .foregroundStyle(text)
        .padding(.horizontal, Space.l)
        .frame(minHeight: 58)
        .frame(maxWidth: .infinity)
        .background(fill.opacity(isEnabled ? 1 : 0.35), in: Capsule())
        // Relief « jouet » : un liseré plus sombre sous la pilule, qui s'écrase à l'appui.
        .background(Capsule().fill(fill.opacity(isEnabled ? 1 : 0)).brightness(-0.18)
            .offset(y: configuration.isPressed ? 1 : 4))
        .offset(y: configuration.isPressed ? 3 : 0)
        .shadow(color: fill.opacity(isEnabled ? 0.35 : 0), radius: 14, y: 8)
        .animation(Motion.press, value: configuration.isPressed)
        .contentShape(Capsule())
    }
}

/// Action secondaire : texte gras coloré, sans soulignement.
struct TextLinkStyle: ButtonStyle {
    var color: Color = .brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// Carte ou ligne pressable : elle s'enfonce légèrement.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    /// Violet de marque.
    static var ink: InkButtonStyle { InkButtonStyle() }
    /// Jaune soleil, pour les fonds violets.
    static var sun: InkButtonStyle { InkButtonStyle(fill: .sun, text: .inkFixed) }
    /// Blanc, pour les fonds colorés.
    static var inverted: InkButtonStyle { InkButtonStyle(fill: .paperFixed, text: Color(hex: 0x3A1FB8)) }
    /// Aux couleurs d'un domaine.
    static func domain(_ domainId: String) -> InkButtonStyle {
        InkButtonStyle(fill: DomainPalette.color(domainId), text: DomainPalette.onColor(domainId))
    }
}

extension ButtonStyle where Self == TextLinkStyle {
    static var textLink: TextLinkStyle { TextLinkStyle() }
}

extension ButtonStyle where Self == RowPressStyle {
    static var row: RowPressStyle { RowPressStyle() }
}

// MARK: - Surfaces

extension View {
    /// Carte Pop : surface blanche très arrondie, ombre douce teintée.
    func popCard(padding: CGFloat = Space.m, radius: CGFloat = Radius.m, fill: Color = .paperRaised) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color(hex: 0x3A1FB8).opacity(0.07), radius: 12, y: 6)
    }
}

struct Hairline: View {
    var color: Color = .hairline

    var body: some View {
        Capsule().fill(color).frame(height: 1.5).accessibilityHidden(true)
    }
}

/// Pastille de domaine : pilule colorée, texte blanc.
struct DomainTag: View {
    let domainId: String
    var name: String? = nil
    var onInk = false

    var body: some View {
        Text(name ?? DomainPalette.fallbackName(domainId))
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .foregroundStyle(onInk ? DomainPalette.color(domainId) : DomainPalette.onColor(domainId))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(onInk ? Color.paperFixed : DomainPalette.color(domainId), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

/// Bulle de dialogue (Léon qui parle).
struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .rounded).weight(.bold))
            .foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Circle().fill(Color.paperRaised).frame(width: 12, height: 12).offset(x: -4, y: 2)
            }
            .shadow(color: Color(hex: 0x3A1FB8).opacity(0.08), radius: 8, y: 4)
    }
}

/// Secousse horizontale (mauvaise réponse). `trigger` s'incrémente pour rejouer.
struct Shake: GeometryEffect {
    var travel: CGFloat = 7
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Niveau de connaissance : jauge épaisse arrondie + halo d'incertitude.
struct SkillBar: View {
    let level: Int
    let reliability: Double
    var color: Color = .brand

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let position = width * CGFloat(min(max(level, 0), 100)) / 100
            let spread = width * CGFloat((1 - reliability) * 0.12)
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.14))
                Capsule().fill(color.opacity(0.25))
                    .frame(width: min(position + spread, width))
                Capsule().fill(color).frame(width: max(position, 10))
            }
        }
        .frame(height: 10)
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
            .font(.system(.callout, design: .rounded).weight(.medium))
            .foregroundStyle(Color.white)
            .padding(.horizontal, Space.m)
            .padding(.vertical, 12)
            .background(Color.brand, in: Capsule())
            .shadow(color: Color.brand.opacity(0.3), radius: 10, y: 5)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Montant de graines, avec l'icône de la monnaie (feuille verte).
struct SeedsAmount: View {
    let amount: Int
    var signed = false
    var color: Color = .ink

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill").imageScale(.small).foregroundStyle(Color.correct)
            Text(signed && amount > 0 ? "+\(amount)" : "\(amount)").monospacedDigit()
        }
        .foregroundStyle(color)
        .accessibilityElement()
        .accessibilityLabel("\(amount) \(amount > 1 ? Brand.currencyPlural : Brand.currencySingular)")
    }
}

/// Progression d'une série de questions : pilules qui se remplissent.
struct ProgressPills: View {
    /// Question en cours, à partir de 1.
    let current: Int
    let total: Int
    var color: Color = .brand

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < current ? color : color.opacity(0.18))
                    .frame(width: index == current - 1 ? 22 : 10, height: 8)
            }
        }
        .animation(Motion.bounce, value: current)
        .accessibilityElement()
        .accessibilityLabel("Question \(current) sur \(total)")
    }
}

/// Bouton rond de fermeture.
struct CloseCircle: View {
    var body: some View {
        Image(systemName: "xmark")
            .font(.system(.footnote, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.inkSoft)
            .frame(width: 34, height: 34)
            .background(Color.paperRaised, in: Circle())
            .frame(width: 44, height: 44)
    }
}
