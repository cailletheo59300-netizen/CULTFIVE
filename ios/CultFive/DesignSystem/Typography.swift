import SwiftUI

// Voix Pop : SF Pro Rounded partout, gras et généreux. Chiffres en « heavy ».
// Tout s'appuie sur les text styles : Dynamic Type natif.

extension Font {
    /// Titres d'écran et grands moments.
    static let cfDisplay = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    /// Énoncé d'une question.
    static let cfQuestion = Font.system(.title2, design: .rounded).weight(.bold)
    /// Titres de section.
    static let cfHeadline = Font.system(.title2, design: .rounded).weight(.bold)
    /// Titres secondaires (listes de domaines, noms).
    static let cfTitle3 = Font.system(.title3, design: .rounded).weight(.bold)
    static let cfBody = Font.system(.body, design: .rounded)
    /// Texte de lecture (explications) : un peu plus de corps.
    static let cfReading = Font.system(.body, design: .rounded).weight(.medium)
    static let cfCallout = Font.system(.callout, design: .rounded).weight(.medium)
    static let cfFootnote = Font.system(.footnote, design: .rounded).weight(.medium)
    /// Étiquettes courtes en capitales (catégorie, rubrique).
    static let cfLabel = Font.system(.caption, design: .rounded).weight(.heavy)
    /// Chiffres alignés.
    static let cfNumber = Font.system(.body, design: .rounded).monospacedDigit().weight(.bold)
}

struct LabelCaps: ViewModifier {
    var color: Color = .inkSoft

    func body(content: Content) -> some View {
        content
            .font(.cfLabel)
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    /// Étiquette en petites capitales.
    func labelCaps(_ color: Color = .inkSoft) -> some View {
        modifier(LabelCaps(color: color))
    }

    /// Chiffre géant (score, niveau), arrondi et très gras, qui suit Dynamic Type jusqu'à une limite raisonnable.
    func numeral(size: CGFloat, weight: Font.Weight = .heavy) -> some View {
        modifier(NumeralModifier(baseSize: size, weight: weight))
    }
}

private struct NumeralModifier: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1
    let baseSize: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(.system(size: baseSize * min(scale, 1.4), weight: weight, design: .rounded).monospacedDigit())
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}
