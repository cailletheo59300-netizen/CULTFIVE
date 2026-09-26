import SwiftUI

// Voix éditoriale : New York (serif système) pour ce qui se lit, SF Pro pour ce qui s'utilise.
// Tout s'appuie sur les text styles : Dynamic Type natif.

extension Font {
    /// Titres d'écran et grands moments.
    static let cfDisplay = Font.system(.largeTitle, design: .serif).weight(.bold)
    /// Énoncé d'une question.
    static let cfQuestion = Font.system(.title, design: .serif).weight(.medium)
    /// Titres de section.
    static let cfHeadline = Font.system(.title2, design: .serif).weight(.semibold)
    /// Titres éditoriaux secondaires (listes de domaines, noms).
    static let cfTitle3 = Font.system(.title3, design: .serif).weight(.semibold)
    static let cfBody = Font.system(.body)
    static let cfBodySerif = Font.system(.body, design: .serif)
    static let cfCallout = Font.system(.callout)
    static let cfFootnote = Font.system(.footnote)
    /// Étiquettes en capitales espacées (catégorie, rubrique).
    static let cfLabel = Font.system(.caption, design: .default).weight(.semibold)
    /// Chiffres alignés.
    static let cfNumber = Font.system(.body).monospacedDigit().weight(.semibold)
}

struct LabelCaps: ViewModifier {
    var color: Color = .inkSoft

    func body(content: Content) -> some View {
        content
            .font(.cfLabel)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    /// Étiquette en petites capitales espacées.
    func labelCaps(_ color: Color = .inkSoft) -> some View {
        modifier(LabelCaps(color: color))
    }

    /// Chiffre géant (score, niveau), en New York, qui suit Dynamic Type jusqu'à une limite raisonnable.
    func numeral(size: CGFloat, weight: Font.Weight = .bold) -> some View {
        modifier(NumeralModifier(baseSize: size, weight: weight))
    }
}

private struct NumeralModifier: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1
    let baseSize: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(.system(size: baseSize * min(scale, 1.4), weight: weight, design: .serif).monospacedDigit())
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}
