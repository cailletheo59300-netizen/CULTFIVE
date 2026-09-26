import Foundation

/// État du pavé numérique interne (questions de calcul). Pas de clavier iOS : saisie contrôlée, sans erreur de format.
/// Le texte canonique utilise « . » ; l'affichage utilise le séparateur local et groupe les milliers.
public struct NumericEntry: Equatable, Sendable {
    public private(set) var raw: String = ""
    public private(set) var isNegative = false
    public let maxDecimals: Int
    public let allowNegative: Bool
    public let maxDigits: Int

    public init(maxDecimals: Int = 3, allowNegative: Bool = false, maxDigits: Int = 9) {
        self.maxDecimals = maxDecimals
        self.allowNegative = allowNegative
        self.maxDigits = maxDigits
    }

    public var isEmpty: Bool { raw.isEmpty }

    private var digitCount: Int { raw.filter(\.isNumber).count }
    private var decimalPart: Substring? {
        guard let dot = raw.firstIndex(of: ".") else { return nil }
        return raw[raw.index(after: dot)...]
    }

    public mutating func append(digit: Int) {
        guard (0...9).contains(digit), digitCount < maxDigits else { return }
        if let decimals = decimalPart, decimals.count >= maxDecimals { return }
        if raw == "0" {
            raw = String(digit)  // pas de zéro non significatif
        } else {
            raw.append(String(digit))
        }
    }

    public mutating func appendDecimalSeparator() {
        guard maxDecimals > 0, !raw.contains(".") else { return }
        raw = raw.isEmpty ? "0." : raw + "."
    }

    public mutating func toggleSign() {
        guard allowNegative else { return }
        isNegative.toggle()
    }

    public mutating func backspace() {
        if raw.isEmpty {
            isNegative = false
        } else {
            raw.removeLast()
        }
    }

    public mutating func clear() {
        raw = ""
        isNegative = false
    }

    /// Valeur saisie, ou nil si rien de valide.
    public var value: Decimal? {
        var text = raw
        if text.hasSuffix(".") { text.removeLast() }
        guard !text.isEmpty, let number = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return isNegative ? -number : number
    }

    /// Texte affiché : « 3 600 », « −12,5 », « 0, ».
    public func display(decimalSeparator: String = ",", groupingSeparator: String = "\u{202F}") -> String {
        guard !raw.isEmpty else { return isNegative ? "−" : "" }
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        let integer = String(parts[0])
        var grouped = ""
        for (index, char) in integer.reversed().enumerated() {
            if index > 0 && index % 3 == 0 { grouped.append(contentsOf: groupingSeparator.reversed()) }
            grouped.append(char)
        }
        var result = String(grouped.reversed())
        if parts.count > 1 {
            result += decimalSeparator + parts[1]
        }
        return (isNegative ? "−" : "") + result
    }
}

public enum NumberFormat {
    /// Affiche un nombre de réponse (« 42,195 », « 10 000 ») selon les conventions françaises.
    public static func display(_ value: Double, decimals: Int? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimals ?? 6
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
